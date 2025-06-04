defmodule DbserviceWeb.TagController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Tags
  alias Dbservice.Tags.Tag

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Tag, as: SwaggerSchemaTag

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaTag.tag(),
      SwaggerSchemaTag.tags()
    )
  end

  swagger_path :index do
    get("/api/tag")

    parameters do
      params(:query, :string, "The name of the tag",
        required: false,
        name: "name"
      )

      params(:query, :string, "The description of the tag", required: false, name: "description")
    end

    response(200, "OK", Schema.ref(:Tags))
  end

  def index(conn, params) do
    query =
      from m in Tag,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from u in acc, where: field(u, ^atom) == ^value
        end
      end)

    tag = Repo.all(query)
    json(conn, DbserviceWeb.TagJSON.index(%{tag: tag}))
  end

  swagger_path :create do
    post("/api/tag")

    parameters do
      body(:body, Schema.ref(:Tag), "Tag to create", required: true)
    end

    response(201, "Created", Schema.ref(:Tag))
  end

  def create(conn, params) do
    with {:ok, %Tag{} = tag} <- Tags.create_tag(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/tag/#{tag}")
      |> json(DbserviceWeb.TagJSON.show(%{tag: tag}))
    end
  end

  swagger_path :show do
    get("/api/tag/{tagId}")

    parameters do
      tagId(:path, :integer, "The id of the tag record", required: true)
    end

    response(200, "OK", Schema.ref(:Tag))
  end

  def show(conn, %{"id" => id}) do
    tag = Tags.get_tag!(id)
    json(conn, DbserviceWeb.TagJSON.show(%{tag: tag}))
  end

  swagger_path :update do
    patch("/api/tag/{tagId}")

    parameters do
      tagId(:path, :integer, "The id of the tag record", required: true)
      body(:body, Schema.ref(:Tag), "Tag to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Tag))
  end

  def update(conn, params) do
    tag = Tags.get_tag!(params["id"])

    with {:ok, %Tag{} = tag} <- Tags.update_tag(tag, params) do
      json(conn, DbserviceWeb.TagJSON.show(%{tag: tag}))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/tag/{tagId}")

    parameters do
      tagId(:path, :integer, "The id of the tag record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    tag = Tags.get_tag!(id)

    with {:ok, %Tag{}} <- Tags.delete_tag(tag) do
      send_resp(conn, :no_content, "")
    end
  end
end
