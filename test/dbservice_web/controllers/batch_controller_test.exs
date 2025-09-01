defmodule DbserviceWeb.BatchControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.BatchesFixtures

  alias Dbservice.Batches.Batch

  @create_attrs %{
    name: "some batch name",
    contact_hours_per_week: 30,
    batch_id: "BATCH001",
    parent_id: nil,
    start_date: "2024-01-01",
    end_date: "2024-06-01",
    program_id: nil,
    auth_group_id: nil,
    af_medium: "online"
  }
  @update_attrs %{
    name: "some updated batch name",
    contact_hours_per_week: 35,
    batch_id: "BATCH002",
    parent_id: nil,
    start_date: "2024-02-01",
    end_date: "2024-07-01",
    program_id: nil,
    auth_group_id: nil,
    af_medium: "offline"
  }
  @invalid_attrs %{
    name: nil,
    contact_hours_per_week: nil,
    batch_id: nil,
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    program_id: nil,
    auth_group_id: nil,
    af_medium: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all batches with data", %{conn: conn} do
    batch = batch_fixture()
    conn = get(conn, ~p"/api/batch")
    [head | _] = json_response(conn, 200)

    # field-by-field
    assert head["id"] == batch.id
    assert head["name"] == batch.name
    assert head["contact_hours_per_week"] == batch.contact_hours_per_week
    assert head["batch_id"] == batch.batch_id
    assert head["start_date"] == to_string(batch.start_date)
    # ...etc
  end

  describe "create batch" do
    test "renders batch when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/batch", @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/batch/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some batch name",
               "contact_hours_per_week" => 30,
               "batch_id" => "BATCH001",
               "parent_id" => nil,
               "start_date" => "2024-01-01",
               "end_date" => "2024-06-01",
               "program_id" => nil,
               "auth_group_id" => nil,
               "af_medium" => "online"
             } = response
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/batch", @invalid_attrs)
      assert json_response(conn, 400)["error"] == "Batch ID is required"
    end
  end

  describe "show batch" do
    setup [:create_batch]

    test "renders batch", %{conn: conn, batch: %Batch{id: id}} do
      conn = get(conn, ~p"/api/batch/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some batch name",
               "contact_hours_per_week" => 30,
               "batch_id" => "BATCH001",
               "parent_id" => nil,
               "start_date" => "2024-01-01",
               "end_date" => "2024-06-01",
               "program_id" => nil,
               "auth_group_id" => nil,
               "af_medium" => "online"
             } = response
    end
  end

  describe "update batch" do
    setup [:create_batch]

    test "renders batch when data is valid", %{conn: conn, batch: %Batch{id: id}} do
      conn = put(conn, ~p"/api/batch/#{id}", @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/batch/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some updated batch name",
               "contact_hours_per_week" => 35,
               "batch_id" => "BATCH002",
               "parent_id" => nil,
               "start_date" => "2024-02-01",
               "end_date" => "2024-07-01",
               "program_id" => nil,
               "auth_group_id" => nil,
               "af_medium" => "offline"
             } = response
    end

    test "renders errors when data is invalid", %{conn: conn, batch: %Batch{id: id}} do
      conn = put(conn, ~p"/api/batch/#{id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete batch" do
    setup [:create_batch]

    test "deletes chosen batch", %{conn: conn, batch: %Batch{id: id}} do
      conn = delete(conn, ~p"/api/batch/#{id}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/batch/#{id}")
      end
    end
  end

  defp create_batch(_) do
    batch = batch_fixture()
    %{batch: batch}
  end
end
