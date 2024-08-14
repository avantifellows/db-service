defmodule DbserviceWeb.AuthGroupController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.AuthGroups
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Utils.Util

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.AuthGroup, as: SwaggerSchemaAuthGroup

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaAuthGroup.auth_group(), SwaggerSchemaAuthGroup.auth_groups())
  end

  swagger_path :index do
    get("/api/auth-group")

    parameters do
      params(:query, :string, "The name of the auth-group", required: false, name: "name")

      params(:query, :string, "The locale of the auth-group",
        required: false,
        name: "locale"
      )
    end

    response(200, "OK", Schema.ref(:AuthGroups))
  end

  def index(conn, params) do
    query =
      from m in AuthGroup,
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

    auth_group = Repo.all(query)
    render(conn, "index.json", auth_group: auth_group)
  end

  swagger_path :create do
    post("/api/auth-group")

    parameters do
      body(:body, Schema.ref(:AuthGroup), "AuthGroup to create", required: true)
    end

    response(201, "Created", Schema.ref(:AuthGroup))
  end

  def create(conn, params) do
    case AuthGroups.get_auth_group_by_name(params["name"]) do
      nil ->
        create_new_auth_group(conn, params)

      existing_auth_group ->
        update_existing_auth_group(conn, existing_auth_group, params)
    end
  end

  swagger_path :show do
    get("/api/auth-group/{authGroupId}")

    parameters do
      authGroupId(:path, :integer, "The id of the auth-group record", required: true)
    end

    response(200, "OK", Schema.ref(:AuthGroup))
  end

  def show(conn, %{"id" => id}) do
    auth_group = AuthGroups.get_auth_group!(id)
    render(conn, "show.json", auth_group: auth_group)
  end

  swagger_path :update do
    patch("/api/auth-group/{authGroupId}")

    parameters do
      authGroupId(:path, :integer, "The id of the auth-group record", required: true)
      body(:body, Schema.ref(:AuthGroup), "Auth-Group to create", required: true)
    end

    response(200, "Updated", Schema.ref(:AuthGroup))
  end

  def update(conn, params) do
    auth_group = AuthGroups.get_auth_group!(params["id"])

    with {:ok, %AuthGroup{} = auth_group} <- AuthGroups.update_auth_group(auth_group, params) do
      render(conn, "show.json", auth_group: auth_group)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/auth-group/{authGroupId}")

    parameters do
      authGroupId(:path, :integer, "The id of the auth-group record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    auth_group = AuthGroups.get_auth_group!(id)

    with {:ok, %AuthGroup{}} <- AuthGroups.delete_auth_group(auth_group) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_auth_group(conn, params) do
    with {:ok, %AuthGroup{} = auth_group} <- AuthGroups.create_auth_group(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.auth_group_path(conn, :show, auth_group))
      |> render("show.json", auth_group: auth_group)
    end
  end

  defp update_existing_auth_group(conn, existing_auth_group, params) do
    with {:ok, %AuthGroup{} = auth_group} <-
           AuthGroups.update_auth_group(existing_auth_group, params),
         {:ok, _} <- update_users_for_auth_group(auth_group.id) do
      conn
      |> put_status(:ok)
      |> render("show.json", auth_group: auth_group)
    end
  end

  def update_users_for_auth_group(auth_group_id) do
    Util.update_users_for_group(auth_group_id, "auth_group")
  end
end
