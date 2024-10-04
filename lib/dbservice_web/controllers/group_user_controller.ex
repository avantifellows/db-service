defmodule DbserviceWeb.GroupUserController do
  alias Dbservice.Groups
  alias Dbservice.EnrollmentRecords
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.GroupUsers
  alias Dbservice.Groups.GroupUser
  alias Dbservice.EnrollmentRecords
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  swagger_path :index do
    get("/api/group-user")

    parameters do
      params(:query, :integer, "The id the group type", required: false, name: "group_id")

      params(:query, :integer, "The id the user",
        required: false,
        name: "user_id"
      )
    end

    response(200, "OK", Schema.ref(:GroupUsers))
  end

  def index(conn, params) do
    query =
      from(m in GroupUser,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    group_user = Repo.all(query)
    render(conn, "index.json", group_user: group_user)
  end

  swagger_path :create do
    post("/api/group-user")

    parameters do
      body(:body, Schema.ref(:GroupUsers), "Group user to create", required: true)
    end

    response(201, "Created", Schema.ref(:GroupUsers))
  end

  def create(conn, params) do
    case GroupUsers.get_group_user_by_user_id_and_group_id(params["user_id"], params["group_id"]) do
      nil ->
        create_new_group_user(conn, params)

      existing_group_user ->
        update_existing_group_user(conn, existing_group_user, params)
    end
  end

  swagger_path :show do
    get("/api/group-user/{groupUserId}")

    parameters do
      groupUserId(:path, :integer, "The id of the group user record", required: true)
    end

    response(200, "OK", Schema.ref(:GroupUsers))
  end

  def show(conn, %{"id" => id}) do
    group_user = GroupUsers.get_group_user!(id)
    render(conn, "show.json", group_user: group_user)
  end

  swagger_path :update do
    patch("/api/group-user/{groupUserId}")

    parameters do
      groupUserId(:path, :integer, "The id of the session user", required: true)
      body(:body, Schema.ref(:GroupUsers), "Group user to create", required: true)
    end

    response(200, "Updated", Schema.ref(:GroupUsers))
  end

  def update(conn, params) do
    group_user = GroupUsers.get_group_user!(params["id"])

    with {:ok, %GroupUser{} = group_user} <-
           GroupUsers.update_group_user(group_user, params) do
      render(conn, "show.json", group_user: group_user)
    end
  end

  @doc """
  Updates the `GroupUser` and associated `EnrollmentRecord` for a given user and group type.

  ## Assumptions
    - This method assumes that only one `EnrollmentRecord` will be updated per call.
    - If the `GroupUser` or `EnrollmentRecord` is not found, it returns an error with a `:not_found` status.

  ## Returns
    - Renders the updated `GroupUser` as JSON if both updates succeed.
    - Returns an error tuple if the `GroupUser` or `EnrollmentRecord` is not found.
  """
  def update_by_type(conn, params) do
    user_id = params["user_id"]
    type = params["type"]
    group = Groups.get_group_by_group_id_and_type(params["group_id"], type)
    new_group_id = group.child_id

    # Fetch the GroupUser with the specified user_id and where the group type is the provided type
    group_user =
      GroupUsers.get_group_user_by_user_id_and_type(user_id, type)
      |> List.first()

    # Fetch the EnrollmentRecord with the specified user_id and where the group_type matches the provided type
    enrollment_record =
      from(er in EnrollmentRecord, where: er.user_id == ^user_id and er.group_type == ^type)
      |> Repo.one()

    case {group_user, enrollment_record} do
      {nil, _} ->
        # GroupUser not found
        {:error, :not_found}

      {_, nil} ->
        # EnrollmentRecord not found
        {:error, :not_found}

      {group_user, enrollment_record} ->
        # Update both the GroupUser and the EnrollmentRecord
        with {:ok, %GroupUser{} = updated_group_user} <-
               GroupUsers.update_group_user(group_user, params),
             {:ok, %EnrollmentRecord{} = _updated_enrollment_record} <-
               EnrollmentRecords.update_enrollment_record(enrollment_record, %{
                 "group_id" => new_group_id
               }) do
          render(conn, "show.json", group_user: updated_group_user)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/group-user/{groupUserId}")

    parameters do
      groupUserId(:path, :integer, "The id of the group user record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, params) do
    group_user = GroupUsers.get_group_user!(params["id"])

    with {:ok, %GroupUser{}} <- GroupUsers.delete_group_user(group_user) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_group_user(conn, params) do
    group = Groups.get_group!(params["group_id"])

    enrollment_record = %{
      "group_id" => group.child_id,
      "group_type" => group.type,
      "user_id" => params["user_id"],
      "grade_id" => params["grade_id"],
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    with {:ok, %EnrollmentRecord{} = _} <-
           EnrollmentRecords.create_enrollment_record(enrollment_record) do
      with {:ok, %GroupUser{} = group_user} <- GroupUsers.create_group_user(params) do
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.group_user_path(conn, :show, group_user))
        |> render("show.json", group_user: group_user)
      end
    end
  end

  defp update_existing_group_user(conn, existing_group_user, params) do
    with {:ok, %GroupUser{} = group_user} <-
           GroupUsers.update_group_user(existing_group_user, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", group_user: group_user)
    end
  end

  def batch_create(conn, %{"data" => batch_data}) do
    results = Enum.map(batch_data, &process_group_user(&1))

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    conn
    |> put_status(:ok)
    |> render("batch_result.json", %{
      message: "Batch processing completed",
      successful: successful,
      failed: failed,
      results: results
    })
  end

  defp process_group_user(group_user_data) do
    case GroupUsers.get_group_user_by_user_id_and_group_id(
           group_user_data["user_id"],
           group_user_data["group_id"]
         ) do
      nil ->
        create_new_group_user_from_batch(group_user_data)

      existing_group_user ->
        update_existing_group_user_from_batch(existing_group_user, group_user_data)
    end
  end

  defp create_new_group_user_from_batch(params) do
    group = Groups.get_group!(params["group_id"])

    enrollment_record = %{
      "group_id" => group.child_id,
      "group_type" => group.type,
      "user_id" => params["user_id"],
      "grade_id" => params["grade_id"],
      "academic_year" => params["academic_year"],
      "start_date" => params["start_date"]
    }

    with {:ok, %EnrollmentRecord{} = _} <-
           EnrollmentRecords.create_enrollment_record(enrollment_record),
         {:ok, %GroupUser{} = group_user} <- GroupUsers.create_group_user(params) do
      {:ok, group_user}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp update_existing_group_user_from_batch(existing_group_user, params) do
    case GroupUsers.update_group_user(existing_group_user, params) do
      {:ok, group_user} -> {:ok, group_user}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
