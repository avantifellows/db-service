defmodule DbserviceWeb.BatchController do
  use DbserviceWeb, :controller

  alias Dbservice.Batches
  alias Dbservice.Batches.Batch

  action_fallback DbserviceWeb.FallbackController

  def index(conn, _params) do
    batch = Batches.list_batch()
    render(conn, "index.json", batch: batch)
  end

  def create(conn, %{"batch" => batch_params}) do
    with {:ok, %Batch{} = batch} <- Batches.create_batch(batch_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.batch_path(conn, :show, batch))
      |> render("show.json", batch: batch)
    end
  end

  def show(conn, %{"id" => id}) do
    batch = Batches.get_batch!(id)
    render(conn, "show.json", batch: batch)
  end

  def update(conn, %{"id" => id, "batch" => batch_params}) do
    batch = Batches.get_batch!(id)

    with {:ok, %Batch{} = batch} <- Batches.update_batch(batch, batch_params) do
      render(conn, "show.json", batch: batch)
    end
  end

  def delete(conn, %{"id" => id}) do
    batch = Batches.get_batch!(id)

    with {:ok, %Batch{}} <- Batches.delete_batch(batch) do
      send_resp(conn, :no_content, "")
    end
  end

  def add_users(conn, %{"id" => batch_id, "user_ids" => user_ids}) when is_list(user_ids) do
    with {:ok, %Batch{} = batch} <- Batches.add_users(batch_id, user_ids) do
      render(conn, "show.json", batch: batch)
    end
  end
end
