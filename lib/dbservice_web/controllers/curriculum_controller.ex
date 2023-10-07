defmodule DbserviceWeb.CurriculumController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Curriculums
  alias Dbservice.Curriculums.Curriculum

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Curriculum, as: SwaggerSchemaCurriculum

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaCurriculum.curriculum(),
      SwaggerSchemaCurriculum.curriculums()
    )
  end

  swagger_path :index do
    get("/api/curriculum")

    parameters do
      params(:query, :string, "The name of the curriculum",
        required: false,
        name: "name"
      )

      params(:query, :string, "The code of the curriculum", required: false, name: "code")
    end

    response(200, "OK", Schema.ref(:Curriculums))
  end

  def index(conn, params) do
    query =
      from(m in Curriculum,
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

    curriculum = Repo.all(query)
    render(conn, "index.json", curriculum: curriculum)
  end

  swagger_path :create do
    post("/api/curriculum")

    parameters do
      body(:body, Schema.ref(:Curriculum), "Curriculum to create", required: true)
    end

    response(201, "Created", Schema.ref(:Curriculum))
  end

  def create(conn, params) do
    case params do
      %{"_json" => curriculum_list} ->
        # Handles the case where params is a list of curriculums
        create_curriculums(conn, curriculum_list)

      _ ->
        # Handles the case where params is a single curriculum
        create_curriculum(conn, params)
    end
  end

  swagger_path :show do
    get("/api/curriculum/{curriculumId}")

    parameters do
      curriculumId(:path, :integer, "The id of the curriculum record", required: true)
    end

    response(200, "OK", Schema.ref(:Curriculum))
  end

  def show(conn, %{"id" => id}) do
    curriculum = Curriculums.get_curriculum!(id)
    render(conn, "show.json", curriculum: curriculum)
  end

  swagger_path :update do
    patch("/api/curriculum/{curriculumId}")

    parameters do
      curriculumId(:path, :integer, "The id of the curriculum record", required: true)
      body(:body, Schema.ref(:Curriculum), "Curriculum to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Curriculum))
  end

  def update(conn, params) do
    curriculum = Curriculums.get_curriculum!(params["id"])

    with {:ok, %Curriculum{} = curriculum} <- Curriculums.update_curriculum(curriculum, params) do
      render(conn, "show.json", curriculum: curriculum)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/curriculum/{curriculumId}")

    parameters do
      curriculumId(:path, :integer, "The id of the curriculum record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    curriculum = Curriculums.get_curriculum!(id)

    with {:ok, %Curriculum{}} <- Curriculums.delete_curriculum(curriculum) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_curriculums(conn, curriculum_list) do
    case Curriculums.create_curriculums(curriculum_list) do
      {:ok, curriculums} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.curriculum_path(conn, :index))
        |> render("curriculum.json", curriculum: curriculums)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(DbserviceWeb.ChangesetView, "error.json", changeset: changeset)
    end
  end

  defp create_curriculum(conn, params) do
    with {:ok, %Curriculum{} = curriculum} <- Curriculums.create_curriculum(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.curriculum_path(conn, :show, curriculum))
      |> render("show.json", curriculum: curriculum)
    end
  end
end
