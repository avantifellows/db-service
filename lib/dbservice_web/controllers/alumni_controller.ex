defmodule DbserviceWeb.AlumniController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Alumnis
  alias Dbservice.Alumnis.Alumni

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Alumni, as: SwaggerSchemaAlumni

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaAlumni.alumni(),
      SwaggerSchemaAlumni.alumnis()
    )
  end

  swagger_path :index do
    get("/api/alumni")

    parameters do
      params(:query, :string, "The alumni filter parameters",
        required: false,
        name: "student_id"
      )
    end

    response(200, "OK", Schema.ref(:Alumnis))
  end

  def index(conn, params) do
    query =
      from(m in Alumni,
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

    alumni = Repo.all(query)
    render(conn, :index, alumni: alumni)
  end

  swagger_path :create do
    post("/api/alumni")

    parameters do
      body(:body, Schema.ref(:Alumni), "Alumni to create", required: true)
    end

    response(201, "Created", Schema.ref(:Alumni))
  end

  def create(conn, params) do
    case Alumnis.get_alumni_by_student_id(params["student_id"]) do
      nil ->
        create_new_alumni(conn, params)

      existing_alumni ->
        update_existing_alumni(conn, existing_alumni, params)
    end
  end

  swagger_path :show do
    get("/api/alumni/{alumniId}")

    parameters do
      alumniId(:path, :integer, "The id of the alumni record", required: true)
    end

    response(200, "OK", Schema.ref(:Alumni))
  end

  def show(conn, %{"id" => id}) do
    case Alumnis.get_alumni(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Alumni not found"})

      alumni ->
        render(conn, :show, alumni: alumni)
    end
  end

  swagger_path :update do
    patch("/api/alumni/{alumniId}")

    parameters do
      alumniId(:path, :integer, "The id of the alumni record", required: true)
      body(:body, Schema.ref(:Alumni), "Alumni to update", required: true)
    end

    response(200, "Updated", Schema.ref(:Alumni))
  end

  def update(conn, params) do
    case Alumnis.get_alumni(params["id"]) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Alumni not found"})

      alumni ->
        with {:ok, %Alumni{} = alumni} <- Alumnis.update_alumni(alumni, params) do
          render(conn, :show, alumni: alumni)
        end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/alumni/{alumniId}")

    parameters do
      alumniId(:path, :integer, "The id of the alumni record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    case Alumnis.get_alumni(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Alumni not found"})

      alumni ->
        with {:ok, %Alumni{}} <- Alumnis.delete_alumni(alumni) do
          send_resp(conn, :no_content, "")
        end
    end
  end

  defp create_new_alumni(conn, params) do
    with {:ok, %Alumni{} = alumni} <- Alumnis.create_alumni(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/alumni/#{alumni}")
      |> render(:show, alumni: alumni)
    end
  end

  defp update_existing_alumni(conn, existing_alumni, params) do
    with {:ok, %Alumni{} = alumni} <-
           Alumnis.update_alumni(existing_alumni, params) do
      conn
      |> put_status(:ok)
      |> render(:show, alumni: alumni)
    end
  end
end
