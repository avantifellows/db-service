defmodule DbserviceWeb.ProgramControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.ProgramsFixtures
  import Dbservice.ProductsFixtures

  alias Dbservice.Programs.Program

  @create_attrs %{
    name: "some name",
    target_outreach: 5000,
    donor: "some donor",
    state: "some state",
    model: "some model",
    is_current: true
  }
  @update_attrs %{
    name: "some updated name",
    target_outreach: 6000,
    donor: "some updated donor",
    state: "some updated state",
    model: "some updated model",
    is_current: false
  }
  @invalid_attrs %{
    name: nil,
    target_outreach: nil,
    donor: nil,
    state: nil,
    model: nil,
    is_current: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all programs with data", %{conn: conn} do
      program = program_fixture()
      conn = get(conn, ~p"/api/program")
      resp = json_response(conn, 200)
      assert Enum.any?(resp, fn p -> p["id"] == program.id end)
      found_program = Enum.find(resp, fn p -> p["id"] == program.id end)

      assert found_program["name"] == program.name
      assert found_program["target_outreach"] == program.target_outreach
      assert found_program["donor"] == program.donor
      assert found_program["state"] == program.state
      assert found_program["model"] == program.model
      assert found_program["is_current"] == program.is_current
      assert found_program["product_id"] == program.product_id
    end
  end

  describe "create program" do
    test "renders program when data is valid", %{conn: conn} do
      # Create a product first
      product = product_fixture()
      create_attrs = Map.put(@create_attrs, :product_id, product.id)

      conn = post(conn, ~p"/api/program", create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/program/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some name",
               "target_outreach" => 5000,
               "donor" => "some donor",
               "state" => "some state",
               "model" => "some model",
               "is_current" => true
             } = response

      assert response["product_id"] == product.id
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/program", @invalid_attrs)
      assert json_response(conn, 400)["error"] == "Program name is required"
    end
  end

  describe "show program" do
    setup [:create_program]

    test "renders program", %{conn: conn, program: %Program{id: id}} do
      conn = get(conn, ~p"/api/program/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some name",
               "target_outreach" => 5000,
               "donor" => "some donor",
               "state" => "some state",
               "model" => "some model",
               "is_current" => true
             } = response

      assert Map.has_key?(response, "product_id")
      refute is_nil(response["product_id"])
    end
  end

  describe "update program" do
    setup [:create_program]

    test "renders program when data is valid", %{conn: conn, program: %Program{id: id}} do
      conn = put(conn, ~p"/api/program/#{id}", @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/program/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "target_outreach" => 6000,
               "donor" => "some updated donor",
               "state" => "some updated state",
               "model" => "some updated model",
               "is_current" => false
             } = response

      assert Map.has_key?(response, "product_id")
      refute is_nil(response["product_id"])
    end

    test "renders errors when data is invalid", %{conn: conn, program: %Program{id: id}} do
      conn = put(conn, ~p"/api/program/#{id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete program" do
    setup [:create_program]

    test "deletes chosen program", %{conn: conn, program: %Program{id: id}} do
      conn = delete(conn, ~p"/api/program/#{id}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/program/#{id}")
      end
    end
  end

  defp create_program(_) do
    program = program_fixture()
    %{program: program}
  end
end
