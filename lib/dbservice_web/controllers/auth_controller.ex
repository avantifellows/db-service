defmodule DbserviceWeb.AuthController do
  @moduledoc """
  Google SSO endpoints for the `/imports` admin UI.

  Ueberauth handles the redirect to Google and the token exchange; this
  controller only decides whether the returned profile is allowed in.
  """

  use DbserviceWeb, :controller

  require Logger

  alias DbserviceWeb.UserAuth

  plug(Ueberauth when action in [:request, :callback])

  @doc """
  The sign-in page.

  `require_authenticated_user` sends people here rather than straight to
  Google, so a misconfigured OAuth client shows a page instead of bouncing
  the browser between two redirects.
  """
  def new(conn, _params) do
    conn
    |> put_layout(false)
    |> render(:new, allowed_domain: UserAuth.allowed_domain())
  end

  @doc """
  Fallback for the request phase.

  Ueberauth's plug normally intercepts `/auth/google` and redirects to Google
  before this runs, so reaching here means the provider is unknown or the
  strategy is misconfigured (most often missing client credentials).
  """
  def request(conn, _params) do
    conn
    |> put_flash(:error, "Google sign-in is not configured on this server.")
    |> redirect(to: ~p"/signin")
  end

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    Logger.warning("Google SSO failed: #{inspect(failure.errors)}")

    conn
    |> put_flash(:error, "Sign-in failed. Please try again.")
    |> redirect(to: ~p"/signin")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case UserAuth.authorize_email(auth.info.email) do
      {:ok, email} ->
        UserAuth.log_in_user(conn, email, auth.info.name || email)

      {:error, :domain_not_allowed} ->
        Logger.warning("Rejected imports sign-in for out-of-domain account")

        conn
        |> put_flash(
          :error,
          "Only #{UserAuth.allowed_domain()} accounts can access the imports tool."
        )
        |> redirect(to: ~p"/signin")

      {:error, :no_email} ->
        conn
        |> put_flash(:error, "Google did not return an email address for that account.")
        |> redirect(to: ~p"/signin")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "Sign-in failed. Please try again.")
    |> redirect(to: ~p"/signin")
  end

  def logout(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> put_flash(:info, "Signed out.")
    |> redirect(to: ~p"/signin")
  end
end
