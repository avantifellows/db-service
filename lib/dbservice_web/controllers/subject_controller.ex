defmodule DbserviceWeb.SubjectController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Subjects
  alias Dbservice.Subjects.Subject

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Subject, as: SwaggerSchemaSubject

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaSubject.subject(),
      SwaggerSchemaSubject.subjects()
    )
  end

  swagger_path :index do
    get("/api/subject")

    parameters do
      params(:query, :string, "The subject of a grade",
        required: false,
        name: "name"
      )

      params(:query, :string, "The code of the subject",
        required: false,
        name: "code"
      )
    end

    response(200, "OK", Schema.ref(:Subjects))
  end

  def index(conn, params) do
    query =
      from(m in Subject,
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

    subject = Repo.all(query)
    render(conn, :index, subject: subject)
  end

  swagger_path :create do
    post("/api/subject")

    parameters do
      body(:body, Schema.ref(:Subject), "Subject to create", required: true)
    end

    response(201, "Created", Schema.ref(:Subject))
  end

  def create(conn, params) do
    case Subjects.get_subject_by_name(params["name"]) do
      nil ->
        create_new_subject(conn, params)

      existing_subject ->
        update_existing_subject(conn, existing_subject, params)
    end
  end

  swagger_path :show do
    get("/api/subject/{subjectId}")

    parameters do
      subjectId(:path, :integer, "The id of the subject record", required: true)
    end

    response(200, "OK", Schema.ref(:Subject))
  end

  def show(conn, %{"id" => id}) do
    subject = Subjects.get_subject!(id)
    render(conn, :show, subject: subject)
  end

  swagger_path :update do
    patch("/api/subject/{subjectId}")

    parameters do
      subjectId(:path, :integer, "The id of the subject record", required: true)
      body(:body, Schema.ref(:Subject), "Subject to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Subject))
  end

  def update(conn, params) do
    subject = Subjects.get_subject!(params["id"])

    with {:ok, %Subject{} = subject} <- Subjects.update_subject(subject, params) do
      render(conn, :show, subject: subject)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/subject/{subjectId}")

    parameters do
      subjectId(:path, :integer, "The id of the subject record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    subject = Subjects.get_subject!(id)

    with {:ok, %Subject{}} <- Subjects.delete_subject(subject) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_subject(conn, params) do
    with {:ok, %Subject{} = subject} <- Subjects.create_subject(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/subject/#{subject}")
      |> render(:show, subject: subject)
    end
  end

  defp update_existing_subject(conn, existing_subject, params) do
    with {:ok, %Subject{} = subject} <-
           Subjects.update_subject(existing_subject, params) do
      conn
      |> put_status(:ok)
      |> render(:show, subject: subject)
    end
  end
end
