defmodule DbserviceWeb.SessionOccurenceController do
  use DbserviceWeb, :controller

  alias Dbservice.Sessions
  alias Dbservice.Sessions.SessionOccurence

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    session_occurence = Sessions.list_session_occurence()
    render(conn, "index.json", session_occurence: session_occurence)
  end

  def create(conn, params) do
    with {:ok, %SessionOccurence{} = session_occurence} <-
           Sessions.create_session_occurence(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.session_occurence_path(conn, :show, session_occurence)
      )
      |> render("show.json", session_occurence: session_occurence)
    end
  end

  def show(conn, %{"id" => id}) do
    session_occurence = Sessions.get_session_occurence!(id)
    render(conn, "show.json", session_occurence: session_occurence)
  end

  def update(conn, params) do
    session_occurence = Sessions.get_session_occurence!(params["id"])

    with {:ok, %SessionOccurence{} = session_occurence} <-
           Sessions.update_session_occurence(session_occurence, params) do
      render(conn, "show.json", session_occurence: session_occurence)
    end
  end

  def delete(conn, %{"id" => id}) do
    session_occurence = Sessions.get_session_occurence!(id)

    with {:ok, %SessionOccurence{}} <- Sessions.delete_session_occurence(session_occurence) do
      send_resp(conn, :no_content, "")
    end
  end
end
