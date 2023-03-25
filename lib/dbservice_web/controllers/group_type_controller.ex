defmodule DbserviceWeb.GroupTypeController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.GroupTypes
  alias Dbservice.Groups.GroupType

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.GroupType, as: SwaggerSchemaGroupType
  alias DbserviceWeb.SwaggerSchema.Group, as: SwaggerSchemaGroup
  alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      Map.merge(
        Map.merge(
          Map.merge(SwaggerSchemaGroupType.group_type(), SwaggerSchemaGroup.groupsessions()),
          Map.merge(SwaggerSchemaCommon.user_ids(), SwaggerSchemaCommon.session_ids())
        ),
        SwaggerSchemaGroup.groupusers()
      ),
      SwaggerSchemaGroupType.group_types()
    )
  end

  swagger_path :index do
    get("/api/group-type")
    response(200, "OK", Schema.ref(:GroupTypes))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    group_type =
      Enum.reduce(param, GroupType, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", group_type: group_type)
  end

  swagger_path :create do
    post("/api/group-type")

    parameters do
      body(:body, Schema.ref(:GroupType), "Group to create", required: true)
    end

    response(201, "Created", Schema.ref(:GroupType))
  end

  def create(conn, params) do
    with {:ok, %GroupType{} = group_type} <- GroupTypes.create_group_type(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.group_path(conn, :show, group_type))
      |> render("show.json", group_type: group_type)
    end
  end

  swagger_path :show do
    get("/api/group-type/{groupTypeId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
    end

    response(200, "OK", Schema.ref(:GroupType))
  end

  def show(conn, %{"id" => id}) do
    group_type = GroupTypes.get_group_type!(id)
    render(conn, "show.json", group_type: group_type)
  end

  swagger_path :update do
    patch("/api/group-type/{groupTypeId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
      body(:body, Schema.ref(:GroupType), "Group to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Group))
  end

  def update(conn, params) do
    group_type = GroupTypes.get_group_type!(params["id"])

    with {:ok, %GroupType{} = group_type} <- GroupTypes.update_group_type(group_type, params) do
      render(conn, "show.json", group_type: group_type)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/group-type/{groupTypeId}")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    group_type = GroupTypes.get_group_type!(id)

    with {:ok, %GroupType{}} <- GroupTypes.delete_group_type(group_type) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :update_users do
    post("/api/group-type/{groupTypeId}/update-users")

    parameters do
      groupTypeId(:path, :integer, "The id of the group", required: true)

      body(:body, Schema.ref(:UserIds), "List of user ids to update for the group", required: true)
    end

    response(200, "OK", Schema.ref(:GroupUsers))
  end

  def update_users(conn, %{"id" => group_id, "user_ids" => user_ids})
      when is_list(user_ids) do
    with {:ok, %GroupType{} = group_type} <- GroupTypes.update_users(group_id, user_ids) do
      render(conn, "show.json", group_type: group_type)
    end
  end

  swagger_path :update_sessions do
    post("/api/group-type/{groupTypeId}/update-sessions")

    parameters do
      groupTypeId(:path, :integer, "The id of the group", required: true)

      body(:body, Schema.ref(:SessionIds), "List of session ids to update for the group",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:GroupSessions))
  end

  def update_sessions(conn, %{"id" => group_id, "session_ids" => session_ids})
      when is_list(session_ids) do
    with {:ok, %GroupType{} = group_type} <- GroupTypes.update_sessions(group_id, session_ids) do
      render(conn, "show.json", group_type: group_type)
    end
  end
end
