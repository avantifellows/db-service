defmodule DbserviceWeb.UserController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.User
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Groups.GroupSession
  alias Dbservice.Groups.Group
  alias Dbservice.Batches.Batch

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

    parameters do
      params(:query, :string, "The email of the user", required: false, name: "email")
      params(:query, :string, "The full name of the user", required: false, name: "full_name")

      params(:query, :date, "The date of birth of the user",
        required: false,
        name: "date_of_birth"
      )

      params(:query, :string, "The phone of the user", required: false, name: "phone")
    end

    response(200, "OK", Schema.ref(:Users))
  end

  def index(conn, params) do
    query =
      from m in User,
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

    user = Repo.all(query)
    render(conn, :index, user: user)
  end

  swagger_path :create do
    post("/api/user")

    parameters do
      body(:body, Schema.ref(:User), "User to create", required: true)
    end

    response(201, "Created", Schema.ref(:User))
  end

  def create(conn, params) do
    case Users.get_user_by_user_id(params["user_id"]) do
      nil ->
        create_new_user(conn, params)

      existing_user ->
        update_existing_user(conn, existing_user, params)
    end
  end

  swagger_path :show do
    get("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user record", required: true)
    end

    response(200, "OK", Schema.ref(:User))
  end

  def show(conn, %{"id" => id}) do
    user = Users.get_user!(id)
    render(conn, :show, user: user)
  end

  swagger_path :update do
    patch("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user record", required: true)
      body(:body, Schema.ref(:User), "User to create", required: true)
    end

    response(200, "Updated", Schema.ref(:User))
  end

  def update(conn, params) do
    user = Users.get_user!(params["id"])

    with {:ok, %User{} = user} <- Users.update_user(user, params) do
      render(conn, :show, user: user)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user/{userId}")

    parameters do
      userId(:path, :integer, "The id of the user record", required: true)
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
      userId(:path, :integer, "The id of the user record", required: true)

      body(:body, Schema.ref(:GroupIds), "List of group ids to update for the user",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:User))
  end

  def update_group(conn, %{"id" => user_id, "group_ids" => group_ids})
      when is_list(group_ids) do
    with {:ok, %User{} = user} <- Users.update_group(user_id, group_ids) do
      render(conn, :show, user: user)
    end
  end

  defp create_new_user(conn, params) do
    with {:ok, %User{} = user} <- Users.create_user(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/user/#{user}")
      |> render(:show, user: user)
    end
  end

  defp update_existing_user(conn, existing_user, params) do
    with {:ok, %User{} = user} <- Users.update_user(existing_user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, user: user)
    end
  end

  def get_user_sessions(conn, %{"user_id" => user_id, "quiz" => quiz_flag}) do
    sessions = fetch_user_sessions(user_id, quiz_flag)
    render(conn, :user_sessions, session: sessions)
  end

  def get_user_sessions(conn, %{"user_id" => user_id}) do
    get_user_sessions(conn, %{"user_id" => user_id, "quiz" => false})
  end

  # Single optimized query that fetches all required data in one go
  defp fetch_user_sessions(user_id, quiz_flag) do
    user_batch_data = get_user_batch_data(user_id)

    if Enum.empty?(user_batch_data) do
      []
    else
      if quiz_flag do
        get_quiz_sessions(user_batch_data)
      else
        get_regular_sessions(user_batch_data)
      end
    end
  end

  # Get user's groups with batch information
  defp get_user_batch_data(user_id) do
    from(gu in GroupUser,
      where: gu.user_id == ^user_id,
      join: class_group in Group,
      on: class_group.id == gu.group_id and class_group.type == "batch",
      join: class_batch in Batch,
      on: class_batch.id == class_group.child_id,
      left_join: quiz_group in Group,
      on: quiz_group.child_id == class_batch.parent_id and quiz_group.type == "batch",
      select: %{
        class_group_id: class_group.id,
        class_batch_id: class_batch.batch_id,
        quiz_group_id: quiz_group.id,
        quiz_id: class_batch.parent_id
      }
    )
    |> Repo.all()
  end

  # Get quiz sessions - sessions come from quiz groups, filtered by class batch IDs
  defp get_quiz_sessions(user_batch_data) do
    quiz_group_ids =
      user_batch_data
      |> Enum.map(& &1.quiz_group_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if Enum.empty?(quiz_group_ids) do
      []
    else
      class_batch_ids = Enum.map(user_batch_data, & &1.class_batch_id) |> Enum.uniq()

      quiz_sessions = Dbservice.GroupSessions.fetch_sessions_by_group_ids(quiz_group_ids)

      Enum.filter(quiz_sessions, &quiz_session_filter(&1, class_batch_ids))
    end
  end

  defp quiz_session_filter(session, class_batch_ids) do
    if session.meta_data["batch_id"] != "" do
      session.platform == "quiz" &&
        should_include_session?(session.meta_data["batch_id"], class_batch_ids)
    else
      true
    end
  end

  # Get regular sessions - sessions come from class groups, no additional filtering
  defp get_regular_sessions(user_batch_data) do
    class_group_ids = Enum.map(user_batch_data, & &1.class_group_id) |> Enum.uniq()

    Dbservice.GroupSessions.fetch_sessions_by_group_ids(class_group_ids)
  end

  defp should_include_session?(session_batch_id_string, user_class_batch_ids)
       when is_binary(session_batch_id_string) do
    # Session's batch_id metadata is comma-separated
    session_batch_ids = String.split(session_batch_id_string, ",") |> Enum.map(&String.trim/1)

    # Check if any of the session's batch_ids match any of the user's class batch_ids
    Enum.any?(session_batch_ids, &(&1 in user_class_batch_ids))
  end

  defp should_include_session?(_, _), do: false
end
