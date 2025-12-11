defmodule DbserviceWeb.CmsStatusController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.CmsStatuses
  alias Dbservice.CmsStatuses.CmsStatus

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.CmsStatus, as: SwaggerSchemaCmsStatus

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaCmsStatus.cms_status(),
      SwaggerSchemaCmsStatus.cms_statuses()
    )
  end

  swagger_path :index do
    get("/api/cms-status")

    parameters do
      params(:query, :string, "The name of cms_status",
        required: false,
        name: "name"
      )
    end

    response(200, "OK", Schema.ref(:CmsStatuses))
  end

  def index(conn, params) do
    query =
      from(m in CmsStatus,
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

    cms_status = Repo.all(query)
    render(conn, :index, cms_status: cms_status)
  end

  swagger_path :create do
    post("/api/cms-status")

    parameters do
      body(:body, Schema.ref(:CmsStatus), "CmsStatus to create", required: true)
    end

    response(201, "Created", Schema.ref(:CmsStatus))
  end

  def create(conn, params) do
    with {:ok, %CmsStatus{} = cms_status} <- CmsStatuses.create_cms_status(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/cms-status/#{cms_status}")
      |> render(:show, cms_status: cms_status)
    end
  end

  swagger_path :show do
    get("/api/cms-status/{cmsStatusId}")

    parameters do
      cmsStatusId(:path, :integer, "The id of the cms_status record", required: true)
    end

    response(200, "OK", Schema.ref(:CmsStatus))
  end

  def show(conn, %{"id" => id}) do
    cms_status = CmsStatuses.get_cms_status!(id)
    render(conn, :show, cms_status: cms_status)
  end

  swagger_path :update do
    patch("/api/cms-status/{cmsStatusId}")

    parameters do
      cmsStatusId(:path, :integer, "The id of the cms_status record", required: true)
      body(:body, Schema.ref(:CmsStatus), "CmsStatus to create", required: true)
    end

    response(200, "Updated", Schema.ref(:CmsStatus))
  end

  def update(conn, params) do
    cms_status = CmsStatuses.get_cms_status!(params["id"])

    with {:ok, %CmsStatus{} = cms_status} <- CmsStatuses.update_cms_status(cms_status, params) do
      render(conn, :show, cms_status: cms_status)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/cms-status/{cmsStatusId}")

    parameters do
      cmsStatusId(:path, :integer, "The id of the cms_status record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    cms_status = CmsStatuses.get_cms_status!(id)

    with {:ok, %CmsStatus{}} <- CmsStatuses.delete_cms_status(cms_status) do
      send_resp(conn, :no_content, "")
    end
  end
end
