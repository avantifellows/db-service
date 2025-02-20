defmodule DbserviceWeb.ChapterCurriculumController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ChapterCurriculums.ChapterCurriculum
  alias Dbservice.ChapterCurriculums

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.ChapterCurriculum, as: SwaggerSchemaChapterCurriculum

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaChapterCurriculum.chapter_curriculum(),
      SwaggerSchemaChapterCurriculum.chapter_curriculums()
    )
  end

  swagger_path :index do
    get("/api/chapter-curriculum")

    parameters do
      params(:query, :integer, "The id of the chapter", required: false, name: "chapter_id")
      params(:query, :integer, "The id of the curriculum", required: false, name: "curriculum_id")
    end

    response(200, "OK", Schema.ref(:ChapterCurriculum))
  end

  def index(conn, params) do
    query =
      from(cc in ChapterCurriculum,
        order_by: [asc: cc.id],
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

    chapter_curriculum = Repo.all(query)
    render(conn, "index.json", chapter_curriculum: chapter_curriculum)
  end

  swagger_path :create do
    post("/api/chapter-curriculum")

    parameters do
      body(:body, Schema.ref(:ChapterCurriculum), "Chapter curriculum to create", required: true)
    end

    response(201, "Created", Schema.ref(:ChapterCurriculum))
  end

  def create(conn, params) do
    case ChapterCurriculums.get_chapter_curriculum_by_chapter_id_and_curriculum_id(
           params["chapter_id"],
           params["curriculum_id"]
         ) do
      nil ->
        create_new_chapter_curriculum(conn, params)

      existing_chapter_curriculum ->
        update_existing_chapter_curriculum(conn, existing_chapter_curriculum, params)
    end
  end

  swagger_path :show do
    get("/api/chapter-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the chapter curriculum record", required: true)
    end

    response(200, "OK", Schema.ref(:ChapterCurriculum))
  end

  def show(conn, %{"id" => id}) do
    chapter_curriculum = ChapterCurriculums.get_chapter_curriculum!(id)
    render(conn, "show.json", chapter_curriculum: chapter_curriculum)
  end

  swagger_path :update do
    patch("/api/chapter-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the chapter curriculum", required: true)
      body(:body, Schema.ref(:ChapterCurriculum), "Chapter curriculum to update", required: true)
    end

    response(200, "Updated", Schema.ref(:ChapterCurriculum))
  end

  def update(conn, params) do
    chapter_curriculum = ChapterCurriculums.get_chapter_curriculum!(params["id"])

    with {:ok, %ChapterCurriculum{} = chapter_curriculum} <-
           ChapterCurriculums.update_chapter_curriculum(chapter_curriculum, params) do
      render(conn, "show.json", chapter_curriculum: chapter_curriculum)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/chapter-curriculum/{id}")

    parameters do
      id(:path, :integer, "The id of the chapter curriculum record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    chapter_curriculum = ChapterCurriculums.get_chapter_curriculum!(id)

    with {:ok, %ChapterCurriculum{}} <-
           ChapterCurriculums.delete_chapter_curriculum(chapter_curriculum) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_chapter_curriculum(conn, params) do
    with {:ok, %ChapterCurriculum{} = chapter_curriculum} <-
           ChapterCurriculums.create_chapter_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header(
        "location",
        Routes.chapter_curriculum_path(conn, :show, chapter_curriculum)
      )
      |> render("show.json", chapter_curriculum: chapter_curriculum)
    end
  end

  defp update_existing_chapter_curriculum(conn, existing_chapter_curriculum, params) do
    with {:ok, %ChapterCurriculum{} = chapter_curriculum} <-
           ChapterCurriculums.update_chapter_curriculum(existing_chapter_curriculum, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", chapter_curriculum: chapter_curriculum)
    end
  end
end
