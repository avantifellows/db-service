defmodule DbserviceWeb.ProgramControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.ProgramsFixtures

  alias Dbservice.Programs.Program

  @create_attrs %{
    name: "some name",
    type: "some type",
    sub_type: "some subtype",
    mode: "some mode",
    start_date: "2022-04-28",
    target_outreach: Enum.random(3000..9999),
    product_used: "some product used",
    donor: "some donor",
    state: "some state",
    model: "some model"
  }
  @update_attrs %{
    name: "some updated name",
    type: "some updated type",
    sub_type: "some updated subtype",
    mode: "some updated mode",
    start_date: ~D[2022-04-28],
    target_outreach: Enum.random(3000..9999),
    product_used: "some updated product used",
    donor: "some updated donor",
    state: "some updated state",
    model: "some updated model"
  }
  @invalid_attrs %{
    name: nil,
    type: nil,
    sub_type: nil,
    mode: nil,
    start_date: nil,
    target_outreach: nil,
    product_used: nil,
    donor: nil,
    state: nil,
    model: nil
  }
  @valid_fields [
    "donor",
    "group_id",
    "id",
    "mode",
    "model",
    "name",
    "product_used",
    "start_date",
    "state",
    "sub_type",
    "target_outreach",
    "type"
  ]
  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all programs", %{conn: conn} do
      conn = get(conn, Routes.program_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create program" do
    test "renders program when data is valid", %{conn: conn} do
      conn = post(conn, Routes.program_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.program_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some name",
               "type" => "some type",
               "sub_type" => "some subtype",
               "mode" => "some mode",
               "start_date" => "2022-04-28",
               "product_used" => "some product used",
               "donor" => "some donor",
               "state" => "some state",
               "model" => "some model"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.program_path(conn, :create), program: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update program" do
    setup [:create_program]

    test "renders program when data is valid", %{conn: conn, program: %Program{id: id} = program} do
      conn = put(conn, Routes.program_path(conn, :update, program), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.program_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "type" => "some updated type",
               "sub_type" => "some updated subtype",
               "mode" => "some updated mode",
               "start_date" => "2022-04-28",
               "product_used" => "some updated product used",
               "donor" => "some updated donor",
               "state" => "some updated state",
               "model" => "some updated model"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, program: program} do
      conn = put(conn, Routes.program_path(conn, :update, program), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete group" do
    setup [:create_program]

    test "deletes chosen group", %{conn: conn, program: program} do
      conn = delete(conn, Routes.program_path(conn, :delete, program))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.program_path(conn, :show, program))
      end
    end
  end

  defp create_program(_) do
    program = program_fixture()
    %{program: program}
  end
end
