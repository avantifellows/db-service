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
            name(:string, "Name of a group")
            parent_id(:integer, "ID of a parent")
            type(:string, "Type of a group")
            program_type(:string, "Type of a program")
            program_sub_type(:string, "Sub-type of a program")
            program_mode(:string, "Mode of a program")
            program_start_date(:date, "Starting date of a program")
            program_target_outreach(:integer, "Target outreach for a particular program")
            program_products_used(:string, "Products used in a program")
            program_donor(:string, "Donor of a program")
            batch_contact_hours_per_week(:integer, "Contact hours for a batch in a week")
            group_input_schema(:map, "Input schema")
            group_locale(:string, "The configured locale for the group")
            group_locale_data(:map, "Meta data about locale settings for the group")
          end

          example(%{
            name: "Abhinav Singh",
            parent_id: 1,
            type: "program",
            program_type: "",
            program_sub_type: "",
            program_mode: "Offline",
            program_start_date: 02 / 02 / 2020,
            program_target_outreach: 1000,
            program_products_used: "",
            program_donor: "",
            program_state: "Delhi",
            batch_contact_hours_per_week: "48",
            group_input_schema: %{},
            group_locale: "hi",
            group_locale_data: %{
              "hi" => %{
                "title" => "सत्र के लिए पंजीकरण करें"
              },
              "en" => %{
                "title" => "Register for session"
              }
            }
          })
        end,
      GroupSession:
        swagger_schema do
          title("Group Session")
          description("Relation between group and session")

          properties do
            group_id(:integer, "Id of a particular group")
            session_id(:integer, "Id of a particular group")
          end

          example(%{
            group_id: 1,
            session_id: 1
          })
        end,
      GroupUser:
        swagger_schema do
          title("Group Session")
          description("Relation between group and user")

          properties do
            group_id(:integer, "Id of a particular group")
            user_id(:integer, "Id of a particular group")
            program_manager_id(:integer, "ID of a program manager")
            program_date_of_joining(:utc_datetime, "Date of joining a program")
            program_student_language(:string, "Language used in an enrolled program")
          end

          example(%{
            group_id: 1,
            user_id: 1,
            program_manager_id: 1,
            program_date_of_joining: 01 / 01 / 2020,
            program_student_language: "English"
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

  swagger_path :update_users do
    post("/api/group/{groupId}/update-users")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
      body(:body, Schema.ref(:UserIds), "List of user ids to update", required: true)
    end

    response(200, "OK", Schema.ref(:GroupUser))
  end

  def update_users(conn, %{"group_id" => group_id, "user_id" => user_id}) when is_list(user_id) do
    with {:ok, %GroupUser{} = group_user} <- Groups.update_users(group_id, user_id) do
      render(conn, "show.json", group_user: group_user)
    end
  end

  swagger_path :update_sessions do
    post("/api/group/{groupId}/update-sessions")

    parameters do
      groupId(:path, :integer, "The id of the group", required: true)
      body(:body, Schema.ref(:SessionIds), "List of session ids to update", required: true)
    end

    response(200, "OK", Schema.ref(:GroupSession))
  end

  def update_sessions(conn, %{"group_id" => group_id, "session_id" => session_id})
      when is_list(session_id) do
    with {:ok, %GroupSession{} = group_sesion} <- Groups.update_sessions(group_id, session_id) do
      render(conn, "show.json", group_sesion: group_sesion)
    end
  end
end
