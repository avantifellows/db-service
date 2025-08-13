defmodule DbserviceWeb.ProblemLanguageController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ProblemLanguages
  alias Dbservice.Resources.ProblemLanguage

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.problem_language(),
      SwaggerSchemaResource.problem_languages()
    )
  end

  swagger_path :index do
    get("/api/problem-language")

    parameters do
      params(:query, :integer, "The id the resource", required: false, name: "res_id")

      params(:query, :integer, "The id the chapter",
        required: false,
        name: "lang_id"
      )
    end

    response(200, "OK", Schema.ref(:ProblemLanguages))
  end

  def index(conn, params) do
    query =
      from(m in ProblemLanguage,
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

    problem_language = Repo.all(query)
    render(conn, "index.json", problem_language: problem_language)
  end

  swagger_path :create do
    post("/api/problem-language")

    parameters do
      body(:body, Schema.ref(:ProblemLanguage), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:ProblemLanguage))
  end

  def create(conn, params) do
    case ProblemLanguages.get_problem_language_by_problem_id_and_language_id(
           params["res_id"],
           params["lang_id"]
         ) do
      nil ->
        create_new_problem_language(conn, params)

      existing_problem_language ->
        update_existing_problem_language(conn, existing_problem_language, params)
    end
  end

  swagger_path :show do
    get("/api/problem-language/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:ProblemLanguage))
  end

  def show(conn, %{"id" => id}) do
    problem_language = ProblemLanguages.get_problem_language!(id)
    render(conn, "show.json", problem_language: problem_language)
  end

  swagger_path :update do
    patch("/api/problem-language/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:ProblemLanguage), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:ProblemLanguage))
  end

  def update(conn, params) do
    problem_language = ProblemLanguages.get_problem_language!(params["id"])

    with {:ok, %ProblemLanguage{} = problem_language} <-
           ProblemLanguages.update_problem_language(problem_language, params) do
      render(conn, "show.json", problem_language: problem_language)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/problem-language/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    problem_language = ProblemLanguages.get_problem_language!(id)

    with {:ok, %ProblemLanguage{}} <- ProblemLanguages.delete_problem_language(problem_language) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_problem_language(conn, params) do
    with {:ok, %ProblemLanguage{} = problem_language} <-
           ProblemLanguages.create_problem_language(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/problem-language/#{problem_language}")
      |> render("show.json", problem_language: problem_language)
    end
  end

  defp update_existing_problem_language(conn, existing_problem_language, params) do
    with {:ok, %ProblemLanguage{} = problem_language} <-
           ProblemLanguages.update_problem_language(existing_problem_language, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", problem_language: problem_language)
    end
  end
end
