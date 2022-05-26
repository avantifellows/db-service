defmodule DbserviceWeb.BatchControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.BatchesFixtures

  alias Dbservice.Batches.Batch

  @create_attrs %{
    name: "some name"
  }
  @update_attrs %{
    name: "some updated name"
  }
  @invalid_attrs %{name: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all batch", %{conn: conn} do
      conn = get(conn, Routes.batch_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create batch" do
    test "renders batch when data is valid", %{conn: conn} do
      conn = post(conn, Routes.batch_path(conn, :create), batch: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.batch_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.batch_path(conn, :create), batch: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update batch" do
    setup [:create_batch]

    test "renders batch when data is valid", %{conn: conn, batch: %Batch{id: id} = batch} do
      conn = put(conn, Routes.batch_path(conn, :update, batch), batch: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.batch_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, batch: batch} do
      conn = put(conn, Routes.batch_path(conn, :update, batch), batch: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete batch" do
    setup [:create_batch]

    test "deletes chosen batch", %{conn: conn, batch: batch} do
      conn = delete(conn, Routes.batch_path(conn, :delete, batch))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.batch_path(conn, :show, batch))
      end
    end
  end

  defp create_batch(_) do
    batch = batch_fixture()
    %{batch: batch}
  end
end
