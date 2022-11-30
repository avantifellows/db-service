defmodule DbserviceWeb.UserController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.User

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.User, as: SwaggerSchemaUser
  alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  def swagger_definitions do
    Map.merge(
      Map.merge(
        SwaggerSchemaUser.user(),
        SwaggerSchemaUser.users()
      ),
      SwaggerSchemaCommon.group_ids()
    )
  end

  swagger_path :index do
    get("/api/user")
    response(200, "OK", Schema.ref(:Users))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    user =
      Enum.reduce(param, User, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", user: user)
  end

  swagger_path :create do
    post("/api/user")

    parameters do
      body(:body, Schema.ref(:User), "User to create", required: true)
    end

    response(201, "Created", Schema.ref(:User))
  end

  def create(conn, params) do
    with {:ok, %User{} = user} <- Users.create_user(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end

  swagger_path :show do
    get("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user", required: true)
    end

    response(200, "OK", Schema.ref(:User))
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, "show.json", user: user)
  end

  swagger_path :update do
    patch("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user", required: true)
      body(:body, Schema.ref(:User), "User to create", required: true)
    end

    response(200, "Updated", Schema.ref(:User))
  end

  def update(conn, params) do
    user = Users.get_user!(params["id"])

    with {:ok, %User{} = user} <- Users.update_user(user, params) do
      render(conn, "show.json", user: user)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    user = Users.get_user!(id)

    with {:ok, %User{}} <- Users.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :update_groups do
    post("/api/user/{userId}/update-groups")

    parameters do
      userId(:path, :integer, "The id of the user", required: true)

      body(:body, Schema.ref(:GroupIds), "List of group ids to update for the user",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:User))
  end

  def update_groups(conn, %{"id" => user_id, "group_ids" => group_ids})
      when is_list(group_ids) do
    with {:ok, %User{} = user} <- Users.update_groups(user_id, group_ids) do
      render(conn, "show.json", user: user)
    end
  end
end
