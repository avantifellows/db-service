defmodule DbserviceWeb.UserProfileController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Profiles
  alias Dbservice.Profiles.UserProfile

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.UserProfile, as: SwaggerSchemaUserProfile

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(
      SwaggerSchemaUserProfile.user_profile(),
      SwaggerSchemaUserProfile.user_profiles()
    )
  end

  swagger_path :index do
    get("/api/user-profile")

    parameters do
      params(:query, :string, "The id of the user profile", required: false, name: "id")
      params(:query, :string, "The id of the user", required: false, name: "user_id")

      params(:query, :boolean, "User logged in at least once",
        required: false,
        name: "logged_in_atleast_once"
      )
    end

    response(200, "OK", Schema.ref(:UserProfiles))
  end

  def index(conn, params) do
    query =
      from(m in UserProfile,
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

    user_profile = Repo.all(query)
    render(conn, "index.json", user_profile: user_profile)
  end

  swagger_path :create do
    post("/api/user-profile")

    parameters do
      body(:body, Schema.ref(:UserProfile), "UserProfile to create", required: true)
    end

    response(201, "Created", Schema.ref(:UserProfile))
  end

  def create(conn, params) do
    with {:ok, %UserProfile{} = user_profile} <- Profiles.create_user_profile(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/user/#{user_profile}")
      |> render("show.json", user_profile: user_profile)
    end
  end

  swagger_path :show do
    get("/api/user-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the user profile record", required: true)
    end

    response(200, "OK", Schema.ref(:UserProfile))
  end

  def show(conn, %{"id" => id}) do
    user_profile = Profiles.get_user_profile!(id)
    render(conn, "show.json", user_profile: user_profile)
  end

  swagger_path :update do
    patch("/api/user-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the user profile record", required: true)
      body(:body, Schema.ref(:UserProfile), "User Profile to update to", required: true)
    end

    response(200, "Updated", Schema.ref(:UserProfile))
  end

  def update(conn, params) do
    user_profile = Profiles.get_user_profile!(params["id"])

    with {:ok, %UserProfile{} = user_profile} <-
           Profiles.update_user_profile(user_profile, params) do
      render(conn, "show.json", user_profile: user_profile)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/user-profile/{id}")

    parameters do
      id(:path, :integer, "The id of the user profile record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    user_profile = Profiles.get_user_profile!(id)

    with {:ok, %UserProfile{}} <- Profiles.delete_user_profile(user_profile) do
      send_resp(conn, :no_content, "")
    end
  end
end
