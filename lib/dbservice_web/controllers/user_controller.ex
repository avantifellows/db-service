defmodule DbserviceWeb.UserController do
  use DbserviceWeb, :controller

  alias Dbservice.Users
  alias Dbservice.Users.User

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    user = Users.list_all_users()
    render(conn, "index.json", user: user)
  end

  def create(conn, params) do
    with {:ok, %User{} = user} <- Users.create_user(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, "show.json", user: user)
  end

  def update(conn, params) do
    user = Users.get_user!(params["id"])

    with {:ok, %User{} = user} <- Users.update_user(user, params) do
      render(conn, "show.json", user: user)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = Users.get_user!(id)

    with {:ok, %User{}} <- Users.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_batches(conn, %{"id" => user_id, "batch_ids" => batch_ids})
      when is_list(batch_ids) do
    with {:ok, %User{} = user} <- Users.update_batches(user_id, batch_ids) do
      render(conn, "show.json", user: user)
    end
  end
end
