defmodule DbserviceWeb.GroupController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Groups
  alias Dbservice.Groups.Group

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Group, as: SwaggerSchemaGroup

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaGroup.group(), SwaggerSchemaGroup.groups())
  end

  swagger_path :index do
    get("/api/group")
    response(200, "OK", Schema.ref(:Groups))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    group =
      Enum.reduce(param, Group, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", group: group)
  end

  swagger_path :create do
    post("/api/group")

    parameters do
      body(:body, Schema.ref(:Group), "Group to create", required: true)
    end

    response(201, "Created", Schema.ref(:Group))
  end

  def create(conn, params) do
    with {:ok, %Group{} = group} <- Groups.create_group(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.group_path(conn, :show, group))
      |> render("show.json", group: group)
    end
  end

  swagger_path :show do
    get("/api/group/{groupId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
    end

    response(200, "OK", Schema.ref(:Group))
  end

  def show(conn, %{"id" => id}) do
    group = Groups.get_group!(id)
    render(conn, "show.json", group: group)
  end

  swagger_path :update do
    patch("/api/group/{groupId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
      body(:body, Schema.ref(:Group), "Group to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Group))
  end

  def update(conn, params) do
    group = Groups.get_group!(params["id"])

    with {:ok, %Group{} = group} <- Groups.update_group(group, params) do
      render(conn, "show.json", group: group)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/group/{groupId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    group = Groups.get_group!(id)

    with {:ok, %Group{}} <- Groups.delete_group(group) do
      send_resp(conn, :no_content, "")
    end
  end
end
