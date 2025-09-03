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

  # Single optimized query
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

  # Get user's groups with batch information(support multi-level hierarchy)
  defp get_user_batch_data(user_id) do
    user_id = if is_binary(user_id), do: String.to_integer(user_id), else: user_id
    # First, get all batches in the hierarchy using recursive CTE
    batch_hierarchy_query = """
    WITH RECURSIVE batch_hierarchy AS (
      -- Base case: Get immediate class batches for the user
      SELECT DISTINCT
        cb.id as batch_pk,
        cb.batch_id as batch_id,
        cb.parent_id,
        cg.id as class_group_id,
        0 as level
      FROM group_user gu
      JOIN "group" cg ON cg.id = gu.group_id AND cg.type = 'batch'
      JOIN batch cb ON cb.id = cg.child_id
      WHERE gu.user_id = $1

      UNION ALL

      -- Recursive case: Get parent batches
      SELECT
        pb.id as batch_pk,
        pb.batch_id as batch_id,
        pb.parent_id,
        NULL as class_group_id,
        bh.level + 1 as level
      FROM batch_hierarchy bh
      JOIN batch pb ON pb.id = bh.parent_id
      WHERE bh.parent_id IS NOT NULL
    )
    SELECT
      bh.batch_pk,
      bh.batch_id,
      bh.parent_id,
      bh.class_group_id,
      bh.level,
      qg.id as quiz_group_id
    FROM batch_hierarchy bh
    LEFT JOIN "group" qg ON qg.child_id = bh.batch_pk AND qg.type = 'batch'
    ORDER BY bh.level ASC
    """

    Ecto.Adapters.SQL.query!(Repo, batch_hierarchy_query, [user_id])
    |> transform_hierarchy_result()
  end

  # Transform the raw SQL result into the expected format
  defp transform_hierarchy_result(%{rows: rows, columns: columns}) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(row)
      |> Enum.into(%{})
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    end)
  end

  # Updated quiz sessions to work with multi-level hierarchy
  defp get_quiz_sessions(user_batch_data) do
    # Get all quiz group IDs from the hierarchy
    quiz_group_ids =
      user_batch_data
      |> Enum.map(& &1.quiz_group_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    if Enum.empty?(quiz_group_ids) do
      []
    else
      # Get all batch IDs in the hierarchy for filtering
      all_batch_ids =
        user_batch_data
        |> Enum.map(& &1.batch_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()

      Dbservice.GroupSessions.fetch_sessions_by_group_ids(quiz_group_ids, all_batch_ids)
    end
  end

  # Updated regular sessions to work with multi-level hierarchy
  defp get_regular_sessions(user_batch_data) do
    # Get class group IDs (only level 0 - direct class groups)
    class_group_ids =
      user_batch_data
      |> Enum.filter(&(&1.level == 0 && !is_nil(&1.class_group_id)))
      |> Enum.map(& &1.class_group_id)
      |> Enum.uniq()

    if Enum.empty?(class_group_ids) do
      []
    else
      Dbservice.GroupSessions.fetch_sessions_by_group_ids(class_group_ids)
    end
  end
end
