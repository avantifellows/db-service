defmodule DbserviceWeb.UserAuth do
  @moduledoc """
  Session handling for the `/imports` admin UI.

  Identity comes from Google SSO (see `DbserviceWeb.AuthController`). We only
  ever keep the signed-in person's email and display name in the session
  cookie — there is no local staff account table, so the Workspace domain is
  the membership check.

  Every import record is stamped with the email this module puts in the
  session, which is what makes an import traceable back to a person.
  """

  use DbserviceWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  @session_email_key "current_user_email"
  @session_name_key "current_user_name"
  @return_to_key "user_return_to"

  @doc """
  Puts the signed-in person into the session and sends them where they were
  headed before being bounced to Google.
  """
  def log_in_user(conn, email, name) do
    return_to = get_session(conn, @return_to_key)

    conn
    # Guards against session fixation: the pre-login session id is discarded.
    |> renew_session()
    |> put_session(@session_email_key, email)
    |> put_session(@session_name_key, name)
    |> redirect(to: return_to || ~p"/imports")
  end

  @doc """
  Drops the session. The caller decides where to send the browser next.
  """
  def log_out_user(conn) do
    renew_session(conn)
  end

  @doc """
  Assigns `:current_user_email` and `:current_user_name` from the session.

  Runs on every browser request so templates can show who is signed in, even
  on pages that do not require authentication.
  """
  def fetch_current_user(conn, _opts) do
    case session_identity(conn) do
      {:ok, email, name} ->
        conn
        |> assign(:current_user_email, email)
        |> assign(:current_user_name, name)

      :error ->
        conn
        |> assign(:current_user_email, nil)
        |> assign(:current_user_name, nil)
    end
  end

  @doc """
  Halts the request unless someone from the allowed domain is signed in.
  """
  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user_email] do
      conn
    else
      conn
      |> maybe_store_return_to()
      |> put_flash(:error, "Please sign in to continue.")
      |> redirect(to: ~p"/signin")
      |> halt()
    end
  end

  @doc """
  LiveView equivalent of `require_authenticated_user/2`.
  """
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case identity_from_session(session) do
      {:ok, email, name} ->
        socket =
          socket
          |> Phoenix.Component.assign(:current_user_email, email)
          |> Phoenix.Component.assign(:current_user_name, name)

        {:cont, socket}

      :error ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "Please sign in to continue.")
          |> Phoenix.LiveView.redirect(to: ~p"/signin")

        {:halt, socket}
    end
  end

  @doc """
  Accepts a Google profile only when its email belongs to the allowed domain.

  Google's `hd` parameter is a hint to the account chooser and can be dropped
  by the caller, so the domain is re-checked here against the email Google
  actually returned.
  """
  def authorize_email(nil), do: {:error, :no_email}

  def authorize_email(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()
    domain = allowed_domain()

    cond do
      domain in [nil, ""] -> {:ok, email}
      String.ends_with?(email, "@" <> domain) -> {:ok, email}
      true -> {:error, :domain_not_allowed}
    end
  end

  def allowed_domain, do: imports_auth_config()[:allowed_domain]

  @doc """
  True when the local development bypass is active.

  Requires both the runtime flag and a non-production compile-time
  environment, so exporting `IMPORTS_AUTH_BYPASS` on a production host cannot
  turn authentication off.
  """
  def bypass_enabled? do
    Application.get_env(:dbservice, :env) != :prod and
      imports_auth_config()[:bypass] == true
  end

  def bypass_email, do: imports_auth_config()[:bypass_email] || "dev@localhost"

  defp session_identity(conn) do
    identity_from_session(%{
      @session_email_key => get_session(conn, @session_email_key),
      @session_name_key => get_session(conn, @session_name_key)
    })
  end

  defp identity_from_session(session) do
    case session[@session_email_key] do
      email when is_binary(email) and email != "" ->
        {:ok, email, session[@session_name_key] || email}

      _ ->
        if bypass_enabled?() do
          {:ok, bypass_email(), bypass_email()}
        else
          :error
        end
    end
  end

  defp imports_auth_config, do: Application.get_env(:dbservice, :imports_auth, [])

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, @return_to_key, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end
