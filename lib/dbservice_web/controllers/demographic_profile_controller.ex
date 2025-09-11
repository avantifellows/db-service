defmodule DbserviceWeb.DemographicProfileController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Demographics
  alias Dbservice.Demographics.DemographicProfile

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.DemographicProfile, as: SwaggerSchemaDemographicProfile

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaDemographicProfile.demographic_profile(),
      SwaggerSchemaDemographicProfile.demographic_profiles()
    )
  end

  swagger_path :index do
    get("/api/demographic_profile")

    parameters do
      category(:query, :string, "The category", required: false)
      gender(:query, :string, "Gender", required: false)
    end

    response(200, "OK", Schema.ref(:DemographicProfiles))
  end

  def index(conn, params) do
    query =
      from(dp in DemographicProfile,
        order_by: [asc: dp.id],
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

    demographic_profile = Repo.all(query)
    render(conn, :index, demographic_profile: demographic_profile)
  end

  swagger_path :show do
    get("/api/demographic_profile/{id}")

    parameters do
      id(:path, :integer, "The ID of the demographic profile", required: true)
    end

    response(200, "OK", Schema.ref(:DemographicProfile))
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    demographic_profile = Demographics.get_demographic_profile!(id)
    render(conn, :show, demographic_profile: demographic_profile)
  end

  swagger_path :create do
    post("/api/demographic_profile")

    parameters do
      demographic_profile(
        :body,
        Schema.ref(:DemographicProfile),
        "The demographic profile to create",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:DemographicProfile))
    response(422, "Unprocessable Entity")
  end

  def create(conn, params) do
    # Extract demographic_profile parameters - handle both nested and direct parameter formats
    demographic_profile_params = params["demographic_profile"] || params

    case Demographics.create_demographic_profile(demographic_profile_params) do
      {:ok, demographic_profile} ->
        conn
        |> put_status(:created)
        |> render(:show, demographic_profile: demographic_profile)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :update do
    put("/api/demographic_profile/{id}")

    parameters do
      id(:path, :integer, "The ID of the demographic profile", required: true)

      demographic_profile(
        :body,
        Schema.ref(:DemographicProfile),
        "The demographic profile updates",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:DemographicProfile))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id} = params) do
    # Extract demographic_profile parameters - handle both nested and direct parameter formats
    demographic_profile_params = params["demographic_profile"] || Map.delete(params, "id")
    demographic_profile = Demographics.get_demographic_profile!(id)

    case Demographics.update_demographic_profile(demographic_profile, demographic_profile_params) do
      {:ok, demographic_profile} ->
        render(conn, :show, demographic_profile: demographic_profile)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/demographic_profile/{id}")

    parameters do
      id(:path, :integer, "The ID of the demographic profile", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found")
  end

  def delete(conn, %{"id" => id}) do
    demographic_profile = Demographics.get_demographic_profile!(id)
    {:ok, _demographic_profile} = Demographics.delete_demographic_profile(demographic_profile)

    send_resp(conn, :no_content, "")
  end
end
