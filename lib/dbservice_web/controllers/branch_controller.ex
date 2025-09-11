defmodule DbserviceWeb.BranchController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Branches
  alias Dbservice.Branches.Branch

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Branch, as: SwaggerSchemaBranch

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaBranch.branch(),
      SwaggerSchemaBranch.branches()
    )
  end

  swagger_path :index do
    get("/api/branch")

    parameters do
      name(:query, :string, "Branch name", required: false)
      parent_branch(:query, :string, "Parent branch", required: false)
    end

    response(200, "OK", Schema.ref(:Branches))
  end

  def index(conn, params) do
    query =
      from(b in Branch,
        order_by: [asc: b.id],
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

    branches = Repo.all(query)
    render(conn, :index, branches: branches)
  end

  swagger_path :show do
    get("/api/branch/{id}")

    parameters do
      id(:path, :integer, "The ID of the branch", required: true)
    end

    response(200, "OK", Schema.ref(:Branch))
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    branch = Branches.get_branch!(id)
    render(conn, :show, branch: branch)
  end

  swagger_path :create do
    post("/api/branch")

    parameters do
      branch(:body, Schema.ref(:Branch), "The branch to create or update", required: true)
    end

    response(201, "Created", Schema.ref(:Branch))
    response(200, "Updated (if branch_id already exists)", Schema.ref(:Branch))
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"branch" => branch_params}) do
    case branch_params["branch_id"] do
      nil ->
        create_new_branch(conn, branch_params)

      branch_id ->
        case Branches.get_branch_by_branch_id(branch_id) do
          nil ->
            create_new_branch(conn, branch_params)

          existing_branch ->
            update_existing_branch(conn, existing_branch, branch_params)
        end
    end
  end

  # Handle direct parameters
  def create(conn, branch_params) when is_map(branch_params) do
    case branch_params["branch_id"] do
      nil ->
        create_new_branch(conn, branch_params)

      branch_id ->
        case Branches.get_branch_by_branch_id(branch_id) do
          nil ->
            create_new_branch(conn, branch_params)

          existing_branch ->
            update_existing_branch(conn, existing_branch, branch_params)
        end
    end
  end

  swagger_path :update do
    put("/api/branch/{id}")

    parameters do
      id(:path, :integer, "The ID of the branch", required: true)
      branch(:body, Schema.ref(:Branch), "The branch updates", required: true)
    end

    response(200, "OK", Schema.ref(:Branch))
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "branch" => branch_params}) do
    branch = Branches.get_branch!(id)

    case Branches.update_branch(branch, branch_params) do
      {:ok, branch} ->
        render(conn, :show, branch: branch)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  # Handle direct parameters
  def update(conn, %{"id" => id} = params) do
    branch = Branches.get_branch!(id)
    branch_params = Map.delete(params, "id")

    case Branches.update_branch(branch, branch_params) do
      {:ok, branch} ->
        render(conn, :show, branch: branch)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/branch/{id}")

    parameters do
      id(:path, :integer, "The ID of the branch", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found")
  end

  def delete(conn, %{"id" => id}) do
    branch = Branches.get_branch!(id)
    {:ok, _branch} = Branches.delete_branch(branch)

    send_resp(conn, :no_content, "")
  end

  defp create_new_branch(conn, branch_params) do
    case Branches.create_branch(branch_params) do
      {:ok, branch} ->
        conn
        |> put_status(:created)
        |> render(:show, branch: branch)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end

  defp update_existing_branch(conn, existing_branch, branch_params) do
    case Branches.update_branch(existing_branch, branch_params) do
      {:ok, branch} ->
        conn
        |> put_status(:ok)
        |> render(:show, branch: branch)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(DbserviceWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)
    end
  end
end
