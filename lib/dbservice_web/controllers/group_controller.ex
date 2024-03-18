defmodule DbserviceWeb.GroupController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Groups
  alias Dbservice.Groups.Group

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Group, as: SwaggerSchemaGroup
  alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        Map.merge(
          Map.merge(SwaggerSchemaGroup.group(), SwaggerSchemaGroup.groupsessions()),
          Map.merge(SwaggerSchemaCommon.user_ids(), SwaggerSchemaCommon.session_ids())
        ),
        SwaggerSchemaGroup.groupusers()
      ),
      SwaggerSchemaGroup.groups()
    )
  end

  swagger_path :index do
    get("/api/group")

    parameters do
      params(:query, :string, "The type of the group", required: false, name: "type")

      params(:query, :integer, "The child id of the group",
        required: false,
        name: "child_id"
      )
    end

    response(200, "OK", Schema.ref(:Groups))
  end

  @spec index(Plug.Conn.t(), any) :: Plug.Conn.t()
  def index(conn, params) do
    query =
      from m in Group,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    group = Repo.all(query)
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
      groupId(:path, :integer, "The id of the group record", required: true)
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
      groupId(:path, :integer, "The id of the group record", required: true)
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
      groupId(:path, :integer, "The id of the group record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    group = Groups.get_group!(id)

    with {:ok, %Group{}} <- Groups.delete_group(group) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :update_users do
    post("/api/group/{groupId}/update-users")

    parameters do
      groupId(:path, :integer, "The id of the group record", required: true)

      body(:body, Schema.ref(:UserIds), "List of user ids to update for the group", required: true)
    end

    response(200, "OK", Schema.ref(:GroupUsers))
  end

  def update_users(conn, %{"id" => group_id, "user_ids" => user_ids})
      when is_list(user_ids) do
    with {:ok, %Group{} = group} <- Groups.update_users(group_id, user_ids) do
      render(conn, "show.json", group: group)
    end
  end

  swagger_path :update_sessions do
    post("/api/group/{groupId}/update-sessions")

    parameters do
      groupId(:path, :integer, "The id of the group record", required: true)

      body(:body, Schema.ref(:SessionIds), "List of session ids to update for the group",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:GroupSessions))
  end

  def update_sessions(conn, %{"id" => group_id, "session_ids" => session_ids})
      when is_list(session_ids) do
    with {:ok, %Group{} = group} <- Groups.update_sessions(group_id, session_ids) do
      render(conn, "show.json", group: group)
    end
  end
end
