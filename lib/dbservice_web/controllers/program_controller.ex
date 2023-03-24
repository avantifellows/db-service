defmodule DbserviceWeb.ProgramController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Programs
  alias Dbservice.Programs.Program

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  # alias DbserviceWeb.SwaggerSchema.program, as: SwaggerSchemaprogram
  # alias DbserviceWeb.SwaggerSchema.Common, as: SwaggerSchemaCommon

  # def swagger_definitions do
  #   # merge the required definitions in a pair at a time using the Map.merge/2 function
  #   Map.merge(
  #     Map.merge(
  #       Map.merge(
  #         Map.merge(SwaggerSchemaprogram.program(), SwaggerSchemaprogram.programsessions()),
  #         Map.merge(SwaggerSchemaCommon.user_ids(), SwaggerSchemaCommon.session_ids())
  #       ),
  #       SwaggerSchemaprogram.programusers()
  #     ),
  #     SwaggerSchemaprogram.programs()
  #   )
  # end

  # swagger_path :index do
  #   get("/api/program")
  #   response(200, "OK", Schema.ref(:programs))
  # end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    program =
      Enum.reduce(param, Program, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

    render(conn, "index.json", program: program)
  end

  # swagger_path :create do
  #   post("/api/program")

  #   parameters do
  #     body(:body, Schema.ref(:program), "program to create", required: true)
  #   end

  #   response(201, "Created", Schema.ref(:program))
  # end

  def create(conn, params) do
    with {:ok, %Program{} = program} <- Programs.create_program(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.program_path(conn, :show, program))
      |> render("show.json", program: program)
    end
  end

  # swagger_path :show do
  #   get("/api/program/{programId}")

  #   parameters do
  #     programId(:path, :integer, "The id of the program", required: true)
  #   end

  #   response(200, "OK", Schema.ref(:program))
  # end

  def show(conn, %{"id" => id}) do
    program = Programs.get_program!(id)
    render(conn, "show.json", program: program)
  end

  # swagger_path :update do
  #   patch("/api/program/{programId}")

  #   parameters do
  #     programId(:path, :integer, "The id of the program", required: true)
  #     body(:body, Schema.ref(:program), "program to create", required: true)
  #   end

  #   response(200, "Updated", Schema.ref(:program))
  # end

  def update(conn, params) do
    program = Programs.get_program!(params["id"])

    with {:ok, %Program{} = program} <- Programs.update_program(program, params) do
      render(conn, "show.json", program: program)
    end
  end

  # swagger_path :delete do
  #   PhoenixSwagger.Path.delete("/api/program/{programId}")

  #   parameters do
  #     programId(:path, :integer, "The id of the program", required: true)
  #   end

  #   response(204, "No Content")
  # end

  def delete(conn, %{"id" => id}) do
    program = Programs.get_program!(id)

    with {:ok, %Program{}} <- Programs.delete_program(program) do
      send_resp(conn, :no_content, "")
    end
  end
end
