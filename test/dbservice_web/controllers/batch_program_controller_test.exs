defmodule DbserviceWeb.BatchProgramControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.BatchProgramsFixtures

  alias Dbservice.Batches.BatchProgram

  @create_attrs %{
    batch_id: Enum.random(1..100),
    program_id: Enum.random(1..100)
  }
  @update_attrs %{
    batch_id: Enum.random(1..100),
    program_id: Enum.random(1..100)
  }
  @invalid_attrs %{
    batch_id: nil,
    program_id: nil
  }
  @valid_fields [
    "batch_id",
    "id",
    "program_id"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all batch programs", %{conn: conn} do
      conn = get(conn, Routes.batch_program_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create batch program" do
    test "renders batch program when data is valid", %{conn: conn} do
      conn = post(conn, Routes.batch_program_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.batch_program_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "batch_id" => batch_id,
               "program_id" => program_id
             } = json_response(conn, 200)

      assert Enum.member?(1..100, batch_id) and Enum.member?(1..100, program_id)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.batch_program_path(conn, :create), batch_program: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update batch program" do
    setup [:create_batch_program]

    test "renders batch program when data is valid", %{
      conn: conn,
      batch_program: %BatchProgram{id: id} = batch_program
    } do
      conn = put(conn, Routes.batch_program_path(conn, :update, batch_program), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.batch_program_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "batch_id" => batch_id,
               "program_id" => program_id
             } = json_response(conn, 200)

      assert Enum.member?(1..100, batch_id) and Enum.member?(1..100, program_id)
    end

    test "renders errors when data is invalid", %{conn: conn, batch_program: batch_program} do
      conn = put(conn, Routes.batch_program_path(conn, :update, batch_program), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete batch program" do
    setup [:create_batch_program]

    test "deletes chosen batch program", %{conn: conn, batch_program: batch_program} do
      conn = delete(conn, Routes.batch_program_path(conn, :delete, batch_program))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.batch_program_path(conn, :show, batch_program))
      end
    end
  end

  defp create_batch_program(_) do
    batch_program = batch_program_fixture()
    %{batch_program: batch_program}
  end
end
