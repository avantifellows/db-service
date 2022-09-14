defmodule DbserviceWeb.GroupController do
  use DbserviceWeb, :controller

  alias Dbservice.Groups
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Groups.GroupSession
  alias Dbservice.Groups.Group

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  def swagger_definitions do
    %{
      Group:
        swagger_schema do
          title("Group")
          description("A group in the application")

          properties do
            input_schema(:map, "Input schema")
            locale(:string, "The configured locale for the group")
            locale_data(:map, "Meta data about locale settings for the group")
          end

          example(%{
            input_schema: %{},
            locale: "hi",
            locale_data: %{
              "hi" => %{
                "title" => "सत्र के लिए पंजीकरण करें"
              },
              "en" => %{
                "title" => "Register for session"
              }
            }
          })
        end,
      Groups:
        swagger_schema do
          title("Groups")
          description("All the groups")
          type(:array)
          items(Schema.ref(:Group))
        end
    }
  end

  swagger_path :index do
    get("/api/group")
    response(200, "OK", Schema.ref(:Groups))
  end

  def index(conn, _params) do
    group = Groups.list_group()
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

  def update_users(conn, %{"group_id" => group_id, "user_id" => user_id}) when is_list(user_id) do
    with {:ok, %GroupUser{} = group_user} <- Groups.update_users(group_id, user_id) do
      render(conn, "show.json", group_user: group_user)
    end
  end

  swagger_path :update_sessions do
    post("/api/batch/{batchId}/update-sessions")

    parameters do
      batchId(:path, :integer, "The id of the batch", required: true)
      body(:body, Schema.ref(:SessionIds), "List of session ids to update", required: true)
    end

    response(200, "OK", Schema.ref(:Batch))
  end

  def update_sessions(conn, %{"group_id" => group_id, "session_id" => session_id})
      when is_list(session_id) do
    with {:ok, %GroupSession{} = group_sesion} <- Groups.update_sessions(group_id, session_id) do
      render(conn, "show.json", group_sesion: group_sesion)
    end
  end
end
