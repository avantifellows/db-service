defmodule DbserviceWeb.LanguageController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Languages
  alias Dbservice.Languages.Language

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Language, as: SwaggerSchemaLanguage

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaLanguage.language(),
      SwaggerSchemaLanguage.languages()
    )
  end

  swagger_path :index do
    get("/api/language")

    parameters do
      params(:query, :string, "The name of the Language", required: false, name: "name")
    end

    response(200, "OK", Schema.ref(:Languages))
  end

  def index(conn, params) do
    query =
      from(m in Language,
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

    language = Repo.all(query)
    render(conn, "index.json", language: language)
  end

  swagger_path :create do
    post("/api/language")

    parameters do
      body(:body, Schema.ref(:Language), "Language to create", required: true)
    end

    response(201, "Created", Schema.ref(:Language))
  end

  def create(conn, params) do
    case Languages.get_language_by_name(params["name"]) do
      nil ->
        create_new_language(conn, params)

      existing_language ->
        update_existing_language(conn, existing_language, params)
    end
  end

  swagger_path :show do
    get("/api/language/{languageId}")

    parameters do
      languageId(:path, :integer, "The id of the language", required: true)
    end

    response(200, "OK", Schema.ref(:Language))
  end

  def show(conn, %{"id" => id}) do
    language = Languages.get_language!(id)
    render(conn, "show.json", language: language)
  end

  swagger_path :update do
    patch("/api/language/{languageId}")

    parameters do
      languageId(:path, :integer, "The id of the language", required: true)
      body(:body, Schema.ref(:Language), "Language to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Language))
  end

  def update(conn, params) do
    language = Languages.get_language!(params["id"])

    with {:ok, %Language{} = language} <- Languages.update_language(language, params) do
      render(conn, "show.json", language: language)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/language/{languageId}")

    parameters do
      languageId(:path, :integer, "The id of the Language", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    language = Languages.get_language!(id)

    with {:ok, %Language{}} <- Languages.delete_language(language) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_language(conn, params) do
    with {:ok, %Language{} = language} <- Languages.create_language(params) do
      conn
      |> put_status(:created)
      |> render("show.json", language: language)
    end
  end

  defp update_existing_language(conn, existing_language, params) do
    with {:ok, %Language{} = language} <- Languages.update_language(existing_language, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", language: language)
    end
  end
end
