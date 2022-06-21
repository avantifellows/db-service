defmodule DbserviceWeb.SessionController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Sessions.Session

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    session = Sessions.list_session()
    render(conn, "index.json", session: session)
  end

  def create(conn, %{"session" => session_params}) do
    with {:ok, %Session{} = session} <- Sessions.create_session(session_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.session_path(conn, :show, session))
      |> render("show.json", session: session)
    end
  end

  def show(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)
    render(conn, "show.json", session: session)
  end

  def update(conn, %{"id" => id, "session" => session_params}) do
    session = Sessions.get_session!(id)

    with {:ok, %Session{} = session} <- Sessions.update_session(session, session_params) do
      render(conn, "show.json", session: session)
    end
  end

  def delete(conn, %{"id" => id}) do
    session = Sessions.get_session!(id)

    with {:ok, %Session{}} <- Sessions.delete_session(session) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_batches(conn, %{"id" => session_id, "batch_ids" => batch_ids})
      when is_list(batch_ids) do
    with {:ok, %Session{} = session} <- Sessions.update_batches(session_id, batch_ids) do
      render(conn, "show.json", session: session)
    end
  end
end
