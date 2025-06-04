defmodule DbserviceWeb.SchoolBatchController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.SchoolBatches
  alias Dbservice.SchoolBatches.SchoolBatch

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.School, as: SwaggerSchemaSchool

  def swagger_definitions do
    SwaggerSchemaSchool.schoolbatches()
  end

  swagger_path :index do
    get("/api/school-batch")

    parameters do
      params(:query, :integer, "The id the school", required: false, name: "school_id")

      params(:query, :integer, "The id the batch",
        required: false,
        name: "batch_id"
      )
    end

    response(200, "OK", Schema.ref(:SchoolBatches))
  end

  def index(conn, params) do
    query =
      from(m in SchoolBatch,
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

    school_batch = Repo.all(query)
    json(conn, DbserviceWeb.SchoolBatchJSON.index(%{school_batch: school_batch}))
  end

  swagger_path :create do
    post("/api/school-batch")

    parameters do
      body(:body, Schema.ref(:SchoolBatches), "school_batch to create", required: true)
    end

    response(201, "Created", Schema.ref(:SchoolBatches))
  end

  def create(conn, params) do
    case SchoolBatches.get_school_batch_by_school_id_and_batch_id(
           params["school_id"],
           params["batch_id"]
         ) do
      nil ->
        create_new_school_batch(conn, params)

      existing_school_batch ->
        update_existing_school_batch(conn, existing_school_batch, params)
    end
  end

  swagger_path :show do
    get("/api/school-batch/{schoolBatchId}")

    parameters do
      schoolBatchId(:path, :integer, "The id of the school_batch record", required: true)
    end

    response(200, "OK", Schema.ref(:SchoolBatches))
  end

  def show(conn, %{"id" => id}) do
    school_batch = SchoolBatches.get_school_batch!(id)
    json(conn, DbserviceWeb.SchoolBatchJSON.show(%{school_batch: school_batch}))
  end

  swagger_path :update do
    patch("/api/school-batch/{schoolBatchId}")

    parameters do
      schoolBatchId(:path, :integer, "The id of the school_batch", required: true)
      body(:body, Schema.ref(:SchoolBatches), "school_batch to create", required: true)
    end

    response(200, "Updated", Schema.ref(:SchoolBatches))
  end

  def update(conn, params) do
    school_batch = SchoolBatches.get_school_batch!(params["id"])

    with {:ok, %SchoolBatch{} = school_batch} <-
           SchoolBatches.update_school_batch(school_batch, params) do
      json(conn, DbserviceWeb.SchoolBatchJSON.show(%{school_batch: school_batch}))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/school-batch/{schoolBatchId}")

    parameters do
      schoolBatchId(:path, :integer, "The id of the school_batch record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, params) do
    school_batch = SchoolBatches.get_school_batch!(params["id"])

    with {:ok, %SchoolBatch{}} <- SchoolBatches.delete_school_batch(school_batch) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_school_batch(conn, params) do
    with {:ok, %SchoolBatch{} = school_batch} <- SchoolBatches.create_school_batch(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/school-batch/#{school_batch}")
      |> json(DbserviceWeb.SchoolBatchJSON.show(%{school_batch: school_batch}))
    end
  end

  defp update_existing_school_batch(conn, existing_school_batch, params) do
    with {:ok, %SchoolBatch{} = school_batch} <-
           SchoolBatches.update_school_batch(existing_school_batch, params) do
      conn
      |> put_status(:ok)
      |> json(DbserviceWeb.SchoolBatchJSON.show(%{school_batch: school_batch}))
    end
  end
end
