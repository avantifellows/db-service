defmodule DbserviceWeb.ResourceChapterController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.ResourceChapters
  alias Dbservice.Resources.ResourceChapter

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource_chapter(),
      SwaggerSchemaResource.resource_chapters()
    )
  end

  swagger_path :index do
    get("/api/resource-chapter")

    parameters do
      params(:query, :integer, "The id the resource", required: false, name: "resource_id")

      params(:query, :integer, "The id the chapter",
        required: false,
        name: "chapter_id"
      )
    end

    response(200, "OK", Schema.ref(:ResourceChapters))
  end

  def index(conn, params) do
    query =
      from(m in ResourceChapter,
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

    resource_chapter = Repo.all(query)
    render(conn, "index.json", resource_chapter: resource_chapter)
  end

  swagger_path :create do
    post("/api/resource-chapter")

    parameters do
      body(:body, Schema.ref(:ResourceChapter), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:ResourceChapter))
  end

  def create(conn, params) do
    case ResourceChapters.get_resource_chapter_by_resource_id_and_chapter_id(
           params["resource_id"],
           params["chapter_id"]
         ) do
      nil ->
        create_new_resource_chapter(conn, params)

      existing_resource_chapter ->
        update_existing_resource_chapter(conn, existing_resource_chapter, params)
    end
  end

  swagger_path :show do
    get("/api/resource-chapter/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:ResourceChapter))
  end

  def show(conn, %{"id" => id}) do
    resource_chapter = ResourceChapters.get_resource_chapter!(id)
    render(conn, "show.json", resource_chapter: resource_chapter)
  end

  swagger_path :update do
    patch("/api/resource-chapter/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:ResourceChapter), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:ResourceChapter))
  end

  def update(conn, params) do
    resource_chapter = ResourceChapters.get_resource_chapter!(params["id"])

    with {:ok, %ResourceChapter{} = resource_chapter} <-
           ResourceChapters.update_resource_chapter(resource_chapter, params) do
      render(conn, "show.json", resource_chapter: resource_chapter)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource-chapter/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource_chapter = ResourceChapters.get_resource_chapter!(id)

    with {:ok, %ResourceChapter{}} <- ResourceChapters.delete_resource_chapter(resource_chapter) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource_chapter(conn, params) do
    with {:ok, %ResourceChapter{} = resource_chapter} <-
           ResourceChapters.create_resource_chapter(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/resource-chapter/#{resource_chapter}")
      |> render("show.json", resource_chapter: resource_chapter)
    end
  end

  defp update_existing_resource_chapter(conn, existing_resource_chapter, params) do
    with {:ok, %ResourceChapter{} = resource_chapter} <-
           ResourceChapters.update_resource_chapter(existing_resource_chapter, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource_chapter: resource_chapter)
    end
  end
end
