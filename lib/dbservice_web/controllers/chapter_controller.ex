defmodule DbserviceWeb.ChapterController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Chapters
  alias Dbservice.Chapters.Chapter

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Chapter, as: SwaggerSchemaChapter

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaChapter.chapter(),
      SwaggerSchemaChapter.chapters()
    )
  end

  swagger_path :index do
    get("/api/chapter")

    parameters do
      params(:query, :string, "The chapter of a subject",
        required: false,
        name: "name"
      )

      params(:query, :string, "The code of the chapter",
        required: false,
        name: "code"
      )
    end

    response(200, "OK", Schema.ref(:Chapters))
  end

  def index(conn, params) do
    query =
      from(m in Chapter,
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

    chapter = Repo.all(query)
    render(conn, "index.json", chapter: chapter)
  end

  swagger_path :create do
    post("/api/chapter")

    parameters do
      body(:body, Schema.ref(:Chapter), "Chapter to create", required: true)
    end

    response(201, "Created", Schema.ref(:Chapter))
  end

  def create(conn, params) do
    with {:ok, %Chapter{} = chapter} <- Chapters.create_chapter(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.chapter_path(conn, :show, chapter))
      |> render("show.json", chapter: chapter)
    end
  end

  swagger_path :show do
    get("/api/chapter/{chapterId}")

    parameters do
      chapterId(:path, :integer, "The id of the chapter record", required: true)
    end

    response(200, "OK", Schema.ref(:Chapter))
  end

  def show(conn, %{"id" => id}) do
    chapter = Chapters.get_chapter!(id)
    render(conn, "show.json", chapter: chapter)
  end

  swagger_path :update do
    patch("/api/chapter/{chapterId}")

    parameters do
      chapterId(:path, :integer, "The id of the chapter record", required: true)
      body(:body, Schema.ref(:Chapter), "Chapter to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Chapter))
  end

  def update(conn, params) do
    chapter = Chapters.get_chapter!(params["id"])

    with {:ok, %Chapter{} = chapter} <- Chapters.update_chapter(chapter, params) do
      render(conn, "show.json", chapter: chapter)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/chapter/{chapterId}")

    parameters do
      chapterId(:path, :integer, "The id of the chapter record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    chapter = Chapters.get_chapter!(id)

    with {:ok, %Chapter{}} <- Chapters.delete_chapter(chapter) do
      send_resp(conn, :no_content, "")
    end
  end
end
