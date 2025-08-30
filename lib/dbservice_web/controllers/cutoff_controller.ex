defmodule DbserviceWeb.CutoffController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Cutoffs
  alias Dbservice.Cutoffs.Cutoff

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Cutoff, as: SwaggerSchemaCutoff

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaCutoff.cutoff(),
      SwaggerSchemaCutoff.cutoffs()
    )
  end

  swagger_path :index do
    get("/api/cutoffs")

    parameters do
      cutoff_year(:query, :integer, "Cutoff year", required: false)
      exam_occurrence_id(:query, :integer, "Exam occurrence ID", required: false)
      college_id(:query, :integer, "College ID", required: false)
      branch_id(:query, :integer, "Branch ID", required: false)
      category_id(:query, :integer, "Category ID", required: false)
    end

    response(200, "OK", Schema.ref(:Cutoffs))
  end

  def index(conn, params) do
    query =
      from(c in Cutoff,
        order_by: [asc: c.id],
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

    cutoffs = Repo.all(query)
    render(conn, :index, cutoffs: cutoffs)
  end

  swagger_path :show do
    get("/api/cutoffs/{id}")

    parameters do
      id(:path, :integer, "The ID of the cutoff", required: true)
    end

    response(200, "OK", Schema.ref(:Cutoff))
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    cutoff = Cutoffs.get_cutoff_with_associations!(id)
    render(conn, :show, cutoff: cutoff)
  end

  swagger_path :create do
    post("/api/cutoffs")

    parameters do
      cutoff(:body, Schema.ref(:Cutoff), "The cutoff to create", required: true)
    end

    response(201, "Created", Schema.ref(:Cutoff))
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"cutoff" => cutoff_params}) do
    case Cutoffs.create_cutoff(cutoff_params) do
      {:ok, cutoff} ->
        conn
        |> put_status(:created)
        |> render(:show, cutoff: cutoff)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  # Handle direct parameters
  def create(conn, cutoff_params) when is_map(cutoff_params) do
    case Cutoffs.create_cutoff(cutoff_params) do
      {:ok, cutoff} ->
        conn
        |> put_status(:created)
        |> render(:show, cutoff: cutoff)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :update do
    put("/api/cutoffs/{id}")

    parameters do
      id(:path, :integer, "The ID of the cutoff", required: true)
      cutoff(:body, Schema.ref(:Cutoff), "The cutoff updates", required: true)
    end

    response(200, "OK", Schema.ref(:Cutoff))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "cutoff" => cutoff_params}) do
    cutoff = Cutoffs.get_cutoff!(id)

    case Cutoffs.update_cutoff(cutoff, cutoff_params) do
      {:ok, cutoff} ->
        render(conn, :show, cutoff: cutoff)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  # Handle direct parameters
  def update(conn, %{"id" => id} = params) do
    cutoff = Cutoffs.get_cutoff!(id)
    cutoff_params = Map.delete(params, "id")

    case Cutoffs.update_cutoff(cutoff, cutoff_params) do
      {:ok, cutoff} ->
        render(conn, :show, cutoff: cutoff)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/cutoffs/{id}")

    parameters do
      id(:path, :integer, "The ID of the cutoff", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found")
  end

  def delete(conn, %{"id" => id}) do
    cutoff = Cutoffs.get_cutoff!(id)
    {:ok, _cutoff} = Cutoffs.delete_cutoff(cutoff)

    send_resp(conn, :no_content, "")
  end
end
