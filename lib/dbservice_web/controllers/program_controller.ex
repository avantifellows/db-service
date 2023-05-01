defmodule DbserviceWeb.ProgramController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Programs
  alias Dbservice.Programs.Program

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Program, as: SwaggerSchemaProgram

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaProgram.program(), SwaggerSchemaProgram.programs())
  end

  swagger_path :index do
    get("/api/program?mode=Offline")
    response(200, "OK", Schema.ref(:Programs))
  end

  def index(conn, params) do
    query =
      from m in Program,
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

    program = Repo.all(query)
    render(conn, "index.json", program: program)
  end

  swagger_path :create do
    post("/api/program")

    parameters do
      body(:body, Schema.ref(:Program), "Program to create", required: true)
    end

    response(201, "Created", Schema.ref(:Program))
  end

  def create(conn, params) do
    with {:ok, %Program{} = program} <- Programs.create_program(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.program_path(conn, :show, program))
      |> render("show.json", program: program)
    end
  end

  swagger_path :show do
    get("/api/program/{programId}")

    parameters do
      programId(:path, :integer, "The id of the program record", required: true)
    end

    response(200, "OK", Schema.ref(:Program))
  end

  def show(conn, %{"id" => id}) do
    program = Programs.get_program!(id)
    render(conn, "show.json", program: program)
  end

  swagger_path :update do
    patch("/api/program/{programId}")

    parameters do
      programId(:path, :integer, "The id of the program record", required: true)
      body(:body, Schema.ref(:Program), "Program to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Program))
  end

  def update(conn, params) do
    program = Programs.get_program!(params["id"])

    with {:ok, %Program{} = program} <- Programs.update_program(program, params) do
      render(conn, "show.json", program: program)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/program/{programId}")

    parameters do
      programId(:path, :integer, "The id of the program record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    program = Programs.get_program!(id)

    with {:ok, %Program{}} <- Programs.delete_program(program) do
      send_resp(conn, :no_content, "")
    end
  end
end
