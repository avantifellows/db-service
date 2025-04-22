defmodule DbserviceWeb.ChapterController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Chapters
  alias Dbservice.Chapters.Chapter
  alias Dbservice.ChapterCurriculums.ChapterCurriculum
  alias Dbservice.Utils.Util

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
    base_query =
      from(m in Chapter,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, base_query, fn
        {"curriculum_id", value}, acc ->
          from(u in acc,
            join: cc in ChapterCurriculum,
            on: cc.chapter_id == u.id,
            where: cc.curriculum_id == ^value
          )

        {key, value}, acc ->
          case String.to_existing_atom(key) do
            :offset ->
              acc

            :limit ->
              acc

            :lang_code ->
              acc

            :name ->
              from(u in acc,
                where:
                  fragment(
                    "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'chapter' = ?)",
                    u.name,
                    ^value
                  )
              )

            atom ->
              from(u in acc, where: field(u, ^atom) == ^value)
          end
      end)

    # Language filtering
    query = Util.filter_by_lang(query, params)

    chapters = Repo.all(query)
    render(conn, "index.json", chapter: chapters)
  end

  swagger_path :create do
    post("/api/chapter")

    parameters do
      body(:body, Schema.ref(:Chapter), "Chapter to create", required: true)
    end

    response(201, "Created", Schema.ref(:Chapter))
  end

  def create(conn, params) do
    case Chapters.get_chapter_by_code(params["code"]) do
      nil ->
        create_new_chapter(conn, params)

      existing_chapter ->
        update_existing_chapter(conn, existing_chapter, params)
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
    Repo.transaction(fn ->
      # First delete related chapter_curriculum records
      from(cc in ChapterCurriculum, where: cc.chapter_id == ^id)
      |> Repo.delete_all()

      # Then retrieve and delete the chapter
      chapter = Chapters.get_chapter!(id)
      Chapters.delete_chapter(chapter)
    end)
    |> case do
      {:ok, {:ok, %Chapter{}}} ->
        send_resp(conn, :no_content, "")

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ErrorView)
        |> render("422.json", message: "Failed to delete chapter")
    end
  end

  defp create_new_chapter(conn, params) do
    with {:ok, %Chapter{} = chapter} <- Chapters.create_chapter_with_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.chapter_path(conn, :show, chapter))
      |> render("show.json", chapter: chapter)
    end
  end

  defp update_existing_chapter(conn, existing_chapter, params) do
    with {:ok, %Chapter{} = chapter} <-
           Chapters.update_chapter_with_curriculum(existing_chapter, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", chapter: chapter)
    end
  end
end
