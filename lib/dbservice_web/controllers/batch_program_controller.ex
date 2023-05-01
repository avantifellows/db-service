defmodule DbserviceWeb.BatchProgramController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.BatchPrograms
  alias Dbservice.Batches.BatchProgram

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.BatchProgram, as: SwaggerSchemaBatchProgram

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      SwaggerSchemaBatchProgram.batch_program(),
      SwaggerSchemaBatchProgram.batch_programs()
    )
  end

  swagger_path :index do
    get("/api/batch-program?batch_id=1")
    response(200, "OK", Schema.ref(:BatchPrograms))
  end

  def index(conn, params) do
    query =
      from m in BatchProgram,
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

    batch_program = Repo.all(query)
    render(conn, "index.json", batch_program: batch_program)
  end

  swagger_path :create do
    post("/api/batch-program")

    parameters do
      body(:body, Schema.ref(:BatchProgram), "BatchProgram to create", required: true)
    end

    response(201, "Created", Schema.ref(:BatchProgram))
  end

  def create(conn, params) do
    with {:ok, %BatchProgram{} = batch_program} <- BatchPrograms.create_batch_program(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.batch_program_path(conn, :show, batch_program))
      |> render("show.json", batch_program: batch_program)
    end
  end

  swagger_path :show do
    get("/api/batch-program/{batchProgramId}")

    parameters do
      batchProgramId(:path, :integer, "The id of the batch-program record", required: true)
    end

    response(200, "OK", Schema.ref(:BatchProgram))
  end

  def show(conn, %{"id" => id}) do
    batch_program = BatchPrograms.get_batch_program!(id)
    render(conn, "show.json", batch_program: batch_program)
  end

  swagger_path :update do
    patch("/api/batch-program/{batchProgramId}")

    parameters do
      batchProgramId(:path, :integer, "The id of the batch_program record", required: true)
      body(:body, Schema.ref(:BatchProgram), "batch_program to create", required: true)
    end

    response(200, "Updated", Schema.ref(:BatchProgram))
  end

  def update(conn, params) do
    batch_program = BatchPrograms.get_batch_program!(params["id"])

    with {:ok, %BatchProgram{} = batch_program} <-
           BatchPrograms.update_batch_program(batch_program, params) do
      render(conn, "show.json", batch_program: batch_program)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/batch-program/{batchProgramId}")

    parameters do
      batchProgramId(:path, :integer, "The id of the batch_program record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    batch_program = BatchPrograms.get_batch_program!(id)

    with {:ok, %BatchProgram{}} <- BatchPrograms.delete_batch_program(batch_program) do
      send_resp(conn, :no_content, "")
    end
  end
end
