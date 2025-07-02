defmodule DbserviceWeb.GroupUserController do
  alias Dbservice.Groups
  alias Dbservice.EnrollmentRecords
  alias Dbservice.Services.EnrollmentService
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
    render(conn, :index, group_user: group_user)
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
    render(conn, :show, group_user: group_user)
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
      render(conn, :show, group_user: group_user)
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
    new_group = Groups.get_group_by_group_id_and_type(params["group_id"], type)
    new_group_id = new_group.child_id

    # Fetch all GroupUsers for the specified user_id and type
    group_users = GroupUsers.get_group_user_by_user_id_and_type(user_id, type)

    # Determine which GroupUser to update and fetch the corresponding EnrollmentRecord
    {group_user_to_update, enrollment_record} =
      find_records_to_update(group_users, user_id, type, params)

    case {group_user_to_update, enrollment_record} do
      {nil, _} ->
        {:error, :not_found}

      {_, nil} ->
        {:error, :not_found}

      {group_user, enrollment_record} ->
        update_group_user_and_enrollment(
          conn,
          group_user,
          enrollment_record,
          params,
          new_group_id
        )
    end
  end

  defp find_records_to_update(group_users, user_id, type, params) do
    group_user_to_update =
      case type do
        "batch" ->
          current_batch_pk = params["current_batch_pk"]
          Enum.find(group_users, fn gu -> gu.group.child_id == current_batch_pk end)

        _ ->
          # For non-batch types, just take the first (and likely only) GroupUser
          List.first(group_users)
      end

    # Fetch the corresponding EnrollmentRecord
    enrollment_record =
      case type do
        "batch" ->
          current_batch_pk = params["current_batch_pk"]

          from(er in EnrollmentRecord,
            where:
              er.user_id == ^user_id and
                er.group_type == ^type and
                er.group_id == ^current_batch_pk and
                er.is_current == true
          )
          |> Repo.one()

        _ ->
          from(er in EnrollmentRecord,
            where:
              er.user_id == ^user_id and
                er.group_type == ^type
          )
          |> Repo.one()
      end

    {group_user_to_update, enrollment_record}
  end

  defp update_group_user_and_enrollment(conn, group_user, enrollment_record, params, new_group_id) do
    Repo.transaction(fn ->
      with {:ok, %GroupUser{} = updated_group_user} <-
             GroupUsers.update_group_user(group_user, %{group_id: params["group_id"]}),
           {:ok, %EnrollmentRecord{} = updated_enrollment_record} <-
             EnrollmentRecords.update_enrollment_record(enrollment_record, %{
               "group_id" => new_group_id
             }) do
        {updated_group_user, updated_enrollment_record}
      else
        {:error, failed_operation} ->
          Repo.rollback(failed_operation)
      end
    end)
    |> case do
      {:ok, {updated_group_user, _updated_enrollment_record}} ->
        render(conn, :show, group_user: updated_group_user)

      {:error, reason} ->
        {:error, reason}
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
    case EnrollmentService.create_new_group_user(params) do
      {:ok, group_user} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/group-user/#{group_user}")
        |> render(:show, group_user: group_user)

      error ->
        error
    end
  end

  defp update_existing_group_user(conn, existing_group_user, params) do
    group = Groups.get_group!(params["group_id"])

    if Map.has_key?(params, "academic_year") and group.type == "school" do
      update_school_enrollment(
        params["user_id"],
        group.child_id,
        params["academic_year"],
        params["start_date"]
      )

      handle_enrollment_record(
        params["user_id"],
        group.child_id,
        group.type,
        params["academic_year"],
        params["start_date"]
      )
    end

    case EnrollmentService.update_existing_group_user(existing_group_user, params) do
      {:ok, group_user} ->
        conn
        |> put_status(:ok)
        |> render(:show, group_user: group_user)

      error ->
        error
    end
  end

  defp update_school_enrollment(user_id, school_id, new_academic_year, end_date) do
    from(er in EnrollmentRecord,
      where:
        er.user_id == ^user_id and
          er.group_id == ^school_id and
          er.group_type == "school" and
          er.academic_year != ^new_academic_year and
          er.is_current == true
    )
    |> Repo.all()
    |> Enum.each(fn record ->
      EnrollmentRecords.update_enrollment_record(record, %{
        "is_current" => false,
        "end_date" => end_date
      })
    end)
  end

  defp handle_enrollment_record(user_id, group_id, group_type, academic_year, start_date) do
    enrollment_record =
      from(er in EnrollmentRecord,
        where:
          er.user_id == ^user_id and
            er.group_id == ^group_id and
            er.group_type == ^group_type and
            er.academic_year == ^academic_year
      )
      |> Repo.one()

    if is_nil(enrollment_record) do
      enrollment_record_params = %{
        "group_id" => group_id,
        "group_type" => group_type,
        "user_id" => user_id,
        "academic_year" => academic_year,
        "start_date" => start_date
      }

      EnrollmentRecords.create_enrollment_record(enrollment_record_params)
    end
  end

  def batch_process(conn, %{"data" => batch_data}) do
    results =
      Enum.map(batch_data, fn data ->
        case EnrollmentService.process_enrollment(data) do
          {:ok, group_user} ->
            {:ok, group_user}

          {:error, error_msg} ->
            {:error, %{error: error_msg, data: data}}
        end
      end)

    successful = Enum.count(results, fn {status, _} -> status == :ok end)
    failed = Enum.count(results, fn {status, _} -> status == :error end)

    conn
    |> put_status(:ok)
    |> render(:batch_result, %{
      message: "Batch processing completed",
      successful: successful,
      failed: failed,
      results: results
    })
  end
end
