defmodule DbserviceWeb.CandidateController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Users
  alias Dbservice.Users.Candidate

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Candidate, as: SwaggerSchemaCandidate

  def swagger_definitions do
    Map.merge(
      Map.merge(
        SwaggerSchemaCandidate.candidate(),
        SwaggerSchemaCandidate.candidates()
      ),
      SwaggerSchemaCandidate.candidate_with_user()
    )
  end

  swagger_path :index do
    get("/api/candidate")

    parameters do
      params(:query, :string, "The ID the candidate",
        required: false,
        name: "candidate_id"
      )

      params(:query, :string, "The degree of the candidate", required: false, name: "degree")
    end

    response(200, "OK", Schema.ref(:Candidates))
  end

  def index(conn, params) do
    query =
      from m in Candidate,
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

    candidate = Repo.all(query)
    render(conn, :index, candidate: candidate)
  end

  swagger_path :create do
    post("/api/candidate")

    parameters do
      body(:body, Schema.ref(:CandidateWithUser), "Candidate to create along with user",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:CandidateWithUser))
  end

  def create(conn, params) do
    case Users.get_candidate_by_candidate_id(params["candidate_id"]) do
      nil ->
        create_candidate_with_user(conn, params)

      existing_candidate ->
        update_existing_candidate_with_user(conn, existing_candidate, params)
    end
  end

  swagger_path :show do
    get("/api/candidate/{id}")

    parameters do
      id(:path, :integer, "The id of the candidate record", required: true)
    end

    response(200, "OK", Schema.ref(:Candidate))
  end

  def show(conn, %{"id" => id}) do
    candidate = Users.get_candidate!(id)
    render(conn, :show, candidate: candidate)
  end

  def update(conn, params) do
    candidate = Users.get_candidate!(params["id"])

    with {:ok, %Candidate{} = candidate} <-
           update_existing_candidate_with_user(conn, candidate, params) do
      render(conn, :show, candidate: candidate)
    end
  end

  swagger_path :update do
    patch("/api/candidate/{id}")

    parameters do
      id(:path, :integer, "The id of the candidate record", required: true)
      body(:body, Schema.ref(:Candidate), "Candidate to update along with user", required: true)
    end

    response(200, "Updated", Schema.ref(:Candidate))
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/candidate/{id}")

    parameters do
      id(:path, :integer, "The id of the candidate record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    candidate = Users.get_candidate!(id)

    with {:ok, %Candidate{}} <- Users.delete_candidate(candidate) do
      send_resp(conn, :no_content, "")
    end
  end

  def update_candidate_with_user(conn, params) do
    candidate = Users.get_candidate!(params["id"])
    user = Users.get_user!(candidate.user_id)

    with {:ok, %Candidate{} = candidate} <-
           Users.update_candidate_with_user(candidate, user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, candidate: candidate)
    end
  end

  defp create_candidate_with_user(conn, params) do
    with {:ok, %Candidate{} = candidate} <- Users.create_candidate_with_user(params) do
      conn
      |> put_status(:created)
      |> render(:show, candidate: candidate)
    end
  end

  defp update_existing_candidate_with_user(conn, existing_candidate, params) do
    user = Users.get_user!(existing_candidate.user_id)

    with {:ok, %Candidate{} = candidate} <-
           Users.update_candidate_with_user(existing_candidate, user, params) do
      conn
      |> put_status(:ok)
      |> render(:show, candidate: candidate)
    end
  end
end
