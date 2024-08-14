defmodule DbserviceWeb.BatchController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Batches
  alias Dbservice.Batches.Batch
  alias Dbservice.Utils.Util

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Batch, as: SwaggerSchemaBatch

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaBatch.batch(), SwaggerSchemaBatch.batches())
  end

  swagger_path :index do
    get("/api/batch")

    parameters do
      params(:query, :string, "The name the batch", required: false, name: "name")

      params(:query, :integer, "The contact hours per week of the batch",
        required: false,
        name: "contact_hours_per_week"
      )
    end

    response(200, "OK", Schema.ref(:Batches))
  end

  def index(conn, params) do
    query =
      from(m in Batch,
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

    batch = Repo.all(query)
    render(conn, "index.json", batch: batch)
  end

  swagger_path :create do
    post("/api/batch")

    parameters do
      body(:body, Schema.ref(:Batch), "Batch to create", required: true)
    end

    response(201, "Created", Schema.ref(:Batch))
  end

  def create(conn, params) do
    case Batches.get_batch_by_batch_id(params["batch_id"]) do
      nil ->
        create_new_batch(conn, params)

      existing_batch ->
        update_existing_batch(conn, existing_batch, params)
    end
  end

  swagger_path :show do
    get("/api/batch/{batchId}")

    parameters do
      batchId(:path, :integer, "The id of the batch record", required: true)
    end

    response(200, "OK", Schema.ref(:Batch))
  end

  def show(conn, %{"id" => id}) do
    batch = Batches.get_batch!(id)
    render(conn, "show.json", batch: batch)
  end

  swagger_path :update do
    patch("/api/batch/{batchId}")

    parameters do
      batchId(:path, :integer, "The id of the batch record", required: true)
      body(:body, Schema.ref(:Batch), "Batch to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Batch))
  end

  def update(conn, params) do
    batch = Batches.get_batch!(params["id"])

    with {:ok, %Batch{} = batch} <- Batches.update_batch(batch, params) do
      render(conn, "show.json", batch: batch)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/batch/{batchId}")

    parameters do
      batchId(:path, :integer, "The id of the batch record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    batch = Batches.get_batch!(id)

    with {:ok, %Batch{}} <- Batches.delete_batch(batch) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_batch(conn, params) do
    with {:ok, %Batch{} = batch} <- Batches.create_batch(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.batch_path(conn, :show, batch))
      |> render("show.json", batch: batch)
    end
  end

  defp update_existing_batch(conn, existing_batch, params) do
    with {:ok, %Batch{} = batch} <- Batches.update_batch(existing_batch, params),
         {:ok, _} <- update_users_for_batch(batch.id) do
      conn
      |> put_status(:ok)
      |> render("show.json", batch: batch)
    end
  end

  def update_users_for_batch(batch_id) do
    Util.update_users_for_group(batch_id, "batch")
  end
end
