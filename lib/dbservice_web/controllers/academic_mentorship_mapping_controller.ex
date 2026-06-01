defmodule DbserviceWeb.AcademicMentorshipMappingController do
  use DbserviceWeb, :controller

  alias Dbservice.AcademicMentorshipMappings
  alias Dbservice.AcademicMentorshipMappings.AcademicMentorshipMapping

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.AcademicMentorshipMapping,
    as: SwaggerSchemaAcademicMentorshipMapping

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaAcademicMentorshipMapping.academic_mentorship_mapping(),
      SwaggerSchemaAcademicMentorshipMapping.academic_mentorship_mappings()
    )
  end

  swagger_path :index do
    get("/api/academic-mentorship-mapping")

    parameters do
      mentor_ids(:query, :string, "Comma-separated mentor IDs", required: false)
      academic_year(:query, :string, "Academic year filter (e.g. 2025-2026)", required: false)
    end

    response(200, "OK", Schema.ref(:AcademicMentorshipMappings))
  end

  def index(conn, params) do
    mentor_ids =
      case params["mentor_ids"] do
        nil ->
          []

        ids_str ->
          ids_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(&1 != ""))
          |> Enum.map(&String.to_integer/1)
      end

    academic_year = params["academic_year"]
    mappings = AcademicMentorshipMappings.list_active_mappings(mentor_ids, academic_year)
    render(conn, :index, mappings: mappings)
  end

  swagger_path :show do
    get("/api/academic-mentorship-mapping/{id}")

    parameters do
      id(:path, :integer, "The mapping ID", required: true)
    end

    response(200, "OK", Schema.ref(:AcademicMentorshipMapping))
  end

  def show(conn, %{"id" => id}) do
    mapping = AcademicMentorshipMappings.get_mapping!(id)
    render(conn, :show, mapping: mapping)
  end

  swagger_path :create do
    post("/api/academic-mentorship-mapping")

    parameters do
      body(:body, Schema.ref(:AcademicMentorshipMapping), "Mapping to create", required: true)
    end

    response(201, "Created", Schema.ref(:AcademicMentorshipMapping))
  end

  def create(conn, params) do
    with {:ok, %AcademicMentorshipMapping{} = mapping} <-
           AcademicMentorshipMappings.create_mapping(params) do
      conn
      |> put_status(:created)
      |> render(:show, mapping: mapping)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        if has_unique_constraint_error?(changeset) do
          conn
          |> put_status(:conflict)
          |> json(%{error: "Mentee already has an active mentor for this academic year"})
        else
          {:error, changeset}
        end
    end
  end

  swagger_path :batch_create do
    post("/api/academic-mentorship-mapping/batch")
    description("Create multiple mappings in a single transaction")

    parameters do
      body(:body, :object, "Batch of mappings to create", required: true)
    end

    response(201, "Created")
  end

  def batch_create(conn, %{"mappings" => mappings_attrs}) when is_list(mappings_attrs) do
    case AcademicMentorshipMappings.create_mappings_batch(mappings_attrs) do
      {:ok, mappings} ->
        conn
        |> put_status(:created)
        |> json(%{
          created: length(mappings),
          mappings: Enum.map(mappings, &render_mapping/1)
        })

      {:error, {:validation_error, changeset, index}} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Batch insert failed",
          failed_index: index,
          details: format_changeset_errors(changeset)
        })

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Batch insert failed"})
    end
  end

  def batch_create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required 'mappings' array"})
  end

  swagger_path :reassign do
    post("/api/academic-mentorship-mapping/reassign")
    description("Atomically reassign a mentee to a different mentor")

    parameters do
      body(:body, :object, "Reassignment details", required: true)
    end

    response(200, "OK", Schema.ref(:AcademicMentorshipMapping))
  end

  def reassign(conn, %{
        "old_mapping_id" => old_mapping_id,
        "new_mentor_id" => new_mentor_id,
        "updated_by" => updated_by
      }) do
    case AcademicMentorshipMappings.reassign_mapping(old_mapping_id, new_mentor_id, updated_by) do
      {:ok, new_mapping} ->
        conn
        |> put_status(:ok)
        |> render(:show, mapping: new_mapping)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Mapping not found"})

      {:error, :already_deleted} ->
        conn |> put_status(:not_found) |> json(%{error: "Mapping already soft-deleted"})

      {:error, {:insert_error, changeset}} ->
        if has_unique_constraint_error?(changeset) do
          conn
          |> put_status(:conflict)
          |> json(%{error: "Mentee already has an active mentor for this academic year"})
        else
          {:error, changeset}
        end

      {:error, _} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Reassignment failed"})
    end
  end

  def reassign(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required fields: old_mapping_id, new_mentor_id, updated_by"})
  end

  swagger_path :soft_delete do
    PhoenixSwagger.Path.delete("/api/academic-mentorship-mapping/{id}")
    description("Soft-delete a mapping (sets deleted_at)")

    parameters do
      id(:path, :integer, "The mapping ID", required: true)
      body(:body, :object, "Must include updated_by", required: true)
    end

    response(200, "OK", Schema.ref(:AcademicMentorshipMapping))
  end

  def soft_delete(conn, %{"id" => id} = params) do
    updated_by = params["updated_by"]

    case AcademicMentorshipMappings.soft_delete_mapping(id, updated_by) do
      {:ok, mapping} ->
        conn
        |> put_status(:ok)
        |> render(:show, mapping: mapping)

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Mapping not found"})

      {:error, :already_deleted} ->
        conn |> put_status(:not_found) |> json(%{error: "Mapping already deleted"})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp has_unique_constraint_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {_field, {_msg, opts}} when is_list(opts) ->
        Keyword.get(opts, :constraint) == :unique

      _ ->
        false
    end)
  end

  defp render_mapping(%AcademicMentorshipMapping{} = mapping) do
    %{
      id: mapping.id,
      mentor_id: mapping.mentor_id,
      mentee_id: mapping.mentee_id,
      academic_year: mapping.academic_year,
      created_by: mapping.created_by,
      updated_by: mapping.updated_by,
      deleted_at: mapping.deleted_at,
      inserted_at: mapping.inserted_at,
      updated_at: mapping.updated_at
    }
  end

  defp format_changeset_errors(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _opts}} -> "#{field}: #{msg}" end)
  end
end
