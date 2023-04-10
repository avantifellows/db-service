defmodule DbserviceWeb.BatchController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Batches
  alias Dbservice.Batches.Batch

  action_fallback DbserviceWeb.FallbackController

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Batch, as: SwaggerSchemaBatch

  def swagger_definitions do
    # merge the required definitions in a pair at a time using the Map.merge/2 function
    Map.merge(SwaggerSchemaBatch.batch(), SwaggerSchemaBatch.batches())
  end

  swagger_path :index do
    get("/api/batch?name=Delhi-12-NEET")
    response(200, "OK", Schema.ref(:Batches))
  end

  def index(conn, params) do
    param = Enum.map(params, fn {key, value} -> {String.to_existing_atom(key), value} end)

    batch =
      Enum.reduce(param, Batch, fn
        {key, value}, query ->
          from u in query, where: field(u, ^key) == ^value

        _, query ->
          query
      end)
      |> Repo.all()

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
    with {:ok, %Batch{} = batch} <- Batches.create_batch(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.batch_path(conn, :show, batch))
      |> render("show.json", batch: batch)
    end
  end

  swagger_path :show do
    get("/api/batch/{batchId}")

    parameters do
      batchId(:path, :integer, "The id of the batch", required: true)
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
      batchId(:path, :integer, "The id of the batch", required: true)
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
      batchId(:path, :integer, "The id of the batch", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    batch = Batches.get_batch!(id)

    with {:ok, %Batch{}} <- Batches.delete_batch(batch) do
      send_resp(conn, :no_content, "")
    end
  end
end
