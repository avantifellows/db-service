defmodule DbserviceWeb.CollegeController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Colleges
  alias Dbservice.Colleges.College

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.College, as: SwaggerSchemaCollege

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaCollege.college(),
      SwaggerSchemaCollege.colleges()
    )
  end

  swagger_path :index do
    get("/api/college")

    parameters do
      params(:query, :string, "The name of the college", required: false, name: "name")
    end

    response(200, "OK", Schema.ref(:Colleges))
  end

  def index(conn, params) do
    query =
      from(m in College,
        order_by: [asc: m.college_id],
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

    college = Repo.all(query)
    render(conn, :index, college: college)
  end

  swagger_path :create do
    post("/api/college")

    parameters do
      body(:body, Schema.ref(:College), "College to create", required: true)
    end

    response(201, "Created", Schema.ref(:College))
  end

  def create(conn, params) do
    case Colleges.get_college_by_college_id(params["college_id"]) do
      nil ->
        create_new_college(conn, params)

      existing_college ->
        update_existing_college(conn, existing_college, params)
    end
  end

  swagger_path :show do
    get("/api/college/{collegeId}")

    parameters do
      collegeId(:path, :string, "The id of the college", required: true)
    end

    response(200, "OK", Schema.ref(:College))
  end

  def show(conn, %{"id" => id}) do
    college = Colleges.get_college!(id)
    render(conn, :show, college: college)
  end

  swagger_path :update do
    patch("/api/college/{collegeId}")

    parameters do
      collegeId(:path, :string, "The id of the college", required: true)
      body(:body, Schema.ref(:College), "College to update", required: true)
    end

    response(200, "Updated", Schema.ref(:College))
  end

  def update(conn, params) do
    college = Colleges.get_college!(params["id"])

    with {:ok, %College{} = college} <- Colleges.update_college(college, params) do
      render(conn, :show, college: college)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/college/{collegeId}")

    parameters do
      collegeId(:path, :string, "The id of the college", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    college = Colleges.get_college!(id)

    with {:ok, %College{}} <- Colleges.delete_college(college) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_college(conn, params) do
    with {:ok, %College{} = college} <- Colleges.create_college(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/college/#{college}")
      |> render(:show, college: college)
    end
  end

  defp update_existing_college(conn, existing_college, params) do
    with {:ok, %College{} = college} <- Colleges.update_college(existing_college, params) do
      conn
      |> put_status(:ok)
      |> render(:show, college: college)
    end
  end
end
