defmodule DbserviceWeb.UserSessionController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Sessions
  alias Dbservice.Sessions.UserSession
  alias Dbservice.Users.User
  alias Dbservice.Users.Student
  alias Dbservice.Groups.GroupUser
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Batches.Batch
  alias Dbservice.Groups.Group

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.UserSession, as: SwaggerSchemaUserSession

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaUserSession.user_session(),
      SwaggerSchemaUserSession.user_sessions()
    )
  end

  swagger_path :index do
    get("/api/user-session")

    parameters do
      params(:query, :integer, "The id the user",
        required: false,
        name: "user_id"
      )
    end

    response(200, "OK", Schema.ref(:UserSessions))
  end

  def index(conn, params) do
    query =
      from m in UserSession,
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

    user_session = Repo.all(query)
    render(conn, :index, user_session: user_session)
  end

  swagger_path :create do
    post("/api/user-session")

    parameters do
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(201, "Created", Schema.ref(:UserSession))
  end

  def create(conn, params) do
    with {:ok, %UserSession{} = user_session} <-
           Sessions.create_user_session(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        ~p"/api/user-session/#{user_session}"
      )
      |> render(:show, user_session: user_session)
    end
  end

  swagger_path :show do
    get("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the user session record", required: true)
    end

    response(200, "OK", Schema.ref(:UserSession))
  end

  def show(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)
    render(conn, :show, user_session: user_session)
  end

  swagger_path :update do
    patch("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the session record", required: true)
      body(:body, Schema.ref(:UserSession), "User session to create", required: true)
    end

    response(200, "Updated", Schema.ref(:UserSession))
  end

  def update(conn, params) do
    user_session = Sessions.get_user_session!(params["id"])

    with {:ok, %UserSession{} = user_session} <-
           Sessions.update_user_session(user_session, params) do
      render(conn, :show, user_session: user_session)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user-session/{userSessionId}")

    parameters do
      userSessionId(:path, :integer, "The id of the user session record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    user_session = Sessions.get_user_session!(id)

    with {:ok, %UserSession{}} <- Sessions.delete_user_session(user_session) do
      send_resp(conn, :no_content, "")
    end
  end

  def cleanup_student(conn, %{"student_id" => student_id}) do
    with {:ok, student} <- get_student(student_id),
         {:ok, user_id} <- extract_user_id(student),
         :ok <- check_if_session_accessed(user_id),
         {:ok, _} <- delete_student_and_related_data(student) do
      send_resp(conn, 200, "Student deleted successfully!")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Student not found"})

      {:error, :session_records_exists} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Active session exists for the user"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error occurred: #{inspect(reason)}"})
    end
  end

  def remove_batch_mapping(conn, %{"student_id" => student_id, "batch_id" => batch_id}) do
    with {:ok, student} <- get_student(student_id),
         {:ok, user_id} <- extract_user_id(student),
         {:ok, batch} <- get_batch(batch_id),
         {:ok, _} <- delete_batch_mappings(user_id, batch) do
      send_resp(conn, 200, "Batch mapping removed successfully!")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Student not found"})

      {:error, :user_id_not_found} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "User ID not found for student"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Error occurred: #{inspect(reason)}"})
    end
  end

  defp get_student(student_id) do
    query = from s in Student, where: s.student_id == ^student_id, limit: 1

    case Repo.one(query) do
      nil -> {:error, :not_found}
      student -> {:ok, student}
    end
  end

  defp extract_user_id(student) do
    case student.user_id do
      nil -> {:error, :user_id_not_found}
      user_id -> {:ok, user_id}
    end
  end

  defp check_if_session_accessed(user_id) do
    if Repo.exists?(from u in UserSession, where: u.user_id == ^user_id) do
      {:error, :session_records_exists}
    else
      :ok
    end
  end

  defp delete_student_and_related_data(student) do
    Repo.transaction(fn ->
      with {:ok, _} <- Repo.delete(student),
           {:ok, _} <- delete_enrollment_record(student.user_id),
           {:ok, _} <- delete_group_user(student.user_id),
           {:ok, _} <- delete_user(student.user_id) do
        {:ok, :deleted}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  defp delete_user(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:ok, :not_found}
      user -> Repo.delete(user)
    end
  end

  defp delete_group_user(user_id) do
    {count, _} = from(gu in GroupUser, where: gu.user_id == ^user_id) |> Repo.delete_all()
    {:ok, count}
  end

  defp delete_enrollment_record(user_id) do
    {count, _} = from(er in EnrollmentRecord, where: er.user_id == ^user_id) |> Repo.delete_all()
    {:ok, count}
  end

  defp get_batch(batch_id) do
    case Repo.get_by(Batch, batch_id: batch_id) do
      nil -> {:error, :batch_not_found}
      batch -> {:ok, batch}
    end
  end

  defp delete_batch_mappings(user_id, batch) do
    Repo.transaction(fn ->
      with {:ok, _} <- delete_batch_group_user(user_id, batch),
           {:ok, _} <- delete_batch_enrollment_record(user_id, batch.id) do
        {:ok, :deleted}
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  defp delete_batch_group_user(user_id, batch) do
    # First get the group_id for this batch from the groups table
    group_query =
      from g in Group,
        where: g.type == "batch" and g.child_id == ^batch.id,
        select: g.id

    case Repo.one(group_query) do
      nil ->
        {:error, :batch_group_not_found}

      group_id ->
        {count, _} =
          from(gu in GroupUser,
            where: gu.user_id == ^user_id and gu.group_id == ^group_id
          )
          |> Repo.delete_all()

        {:ok, count}
    end
  end

  defp delete_batch_enrollment_record(user_id, batch_id) do
    {count, _} =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_type == "batch" and
            er.group_id == ^batch_id
      )
      |> Repo.delete_all()

    {:ok, count}
  end
end
