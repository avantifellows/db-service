defmodule DbserviceWeb.GroupUserController do
  alias Dbservice.Groups
  alias Dbservice.Services.EnrollmentService
  alias Dbservice.Services.GroupUpdateService
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.GroupUsers
  alias Dbservice.Groups.GroupUser

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
    case GroupUpdateService.update_user_group_by_type(params) do
      {:ok, updated_group_user} ->
        render(conn, :show, group_user: updated_group_user)

      {:error, :not_found} ->
        {:error, :not_found}

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
      EnrollmentService.update_school_enrollment(
        params["user_id"],
        group.child_id,
        params["academic_year"],
        params["start_date"]
      )

      EnrollmentService.handle_enrollment_record(
        params["user_id"],
        group.child_id,
        group.type,
        params["academic_year"],
        params["start_date"]
      )
    end

    with {:ok, %GroupUser{} = group_user} <-
           GroupUsers.update_group_user(existing_group_user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, group_user: group_user)
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
