defmodule DbserviceWeb.PurposeController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Purposes
  alias Dbservice.Purposes.Purpose

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Purpose, as: SwaggerSchemaPurpose

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaPurpose.purpose(),
      SwaggerSchemaPurpose.purposes()
    )
  end

  swagger_path :index do
    get("/api/purpose")

    parameters do
      params(:query, :string, "The purpose of the content",
        required: false,
        name: "name"
      )
    end

    response(200, "OK", Schema.ref(:Purposes))
  end

  def index(conn, params) do
    query =
      from(m in Purpose,
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

    purpose = Repo.all(query)
    render(conn, "index.json", purpose: purpose)
  end

  swagger_path :create do
    post("/api/purpose")

    parameters do
      body(:body, Schema.ref(:Purpose), "Purpose to create", required: true)
    end

    response(201, "Created", Schema.ref(:Purpose))
  end

  def create(conn, params) do
    with {:ok, %Purpose{} = purpose} <- Purposes.create_purpose(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.purpose_path(conn, :show, purpose))
      |> render("show.json", purpose: purpose)
    end
  end

  swagger_path :show do
    get("/api/purpose/{purposeId}")

    parameters do
      purposeId(:path, :integer, "The id of the purpose record", required: true)
    end

    response(200, "OK", Schema.ref(:Purpose))
  end

  def show(conn, %{"id" => id}) do
    purpose = Purposes.get_purpose!(id)
    render(conn, "show.json", purpose: purpose)
  end

  swagger_path :update do
    patch("/api/purpose/{purposeId}")

    parameters do
      purposeId(:path, :integer, "The id of the purpose record", required: true)
      body(:body, Schema.ref(:Purpose), "Purpose to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Purpose))
  end

  def update(conn, params) do
    purpose = Purposes.get_purpose!(params["id"])

    with {:ok, %Purpose{} = purpose} <- Purposes.update_purpose(purpose, params) do
      render(conn, "show.json", purpose: purpose)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/purpose/{purposeId}")

    parameters do
      purposeId(:path, :integer, "The id of the purpose record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    purpose = Purposes.get_purpose!(id)

    with {:ok, %Purpose{}} <- Purposes.delete_purpose(purpose) do
      send_resp(conn, :no_content, "")
    end
  end
end
