defmodule DbserviceWeb.UserSessionController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Sessions.UserSession

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    user_session = Sessions.list_user_session()
    render(conn, "index.json", user_session: user_session)
  end

  def create(conn, %{"user_session" => user_session_params}) do
    with {:ok, %UserSession{} = user_session} <-
           Sessions.create_user_session(user_session_params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.user_session_path(conn, :show, user_session)
      )
      |> render("show.json", user_session: user_session)
    end
  end

  def show(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)
    render(conn, "show.json", user_session: user_session)
  end

  def update(conn, %{"id" => id, "user_session" => user_session_params}) do
    user_session = Sessions.get_user_session!(id)

    with {:ok, %UserSession{} = user_session} <-
           Sessions.update_user_session(user_session, user_session_params) do
      render(conn, "show.json", user_session: user_session)
    end
  end

  def delete(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)

    with {:ok, %UserSession{}} <- Sessions.delete_user_session(user_session) do
      send_resp(conn, :no_content, "")
    end
  end
end
