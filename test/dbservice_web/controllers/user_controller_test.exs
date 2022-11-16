defmodule DbserviceWeb.UserControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.Users.User

  @create_attrs %{
    address: "some address",
    city: "some city",
    district: "some district",
    email: "some email",
    full_name: "some full name",
    gender: "some gender",
    phone: "9456591269",
    pincode: "some pincode",
    role: "some role",
    state: "some state",
    whatsapp_phone: "some whatsapp phone",
    date_of_birth: ~U[2022-04-28 13:58:00Z]
  }
  @update_attrs %{
    address: "some updated address",
    city: "some updated city",
    district: "some updated district",
    email: "some updated email",
    full_name: "some updated full name",
    gender: "some updated gender",
    phone: "9456591269",
    pincode: "some updated pincode",
    role: "some updated role",
    state: "some updated state",
    whatsapp_phone: "some updated whatsapp phone",
    date_of_birth: ~U[2022-04-28 13:58:00Z]
  }
  @invalid_attrs %{
    full_name: nil,
    email: nil,
    phone: nil,
    gender: nil,
    address: nil,
    city: nil,
    district: nil,
    state: nil,
    pincode: nil,
    role: nil,
    whatsapp_phone: nil,
    date_of_birth: nil
  }
  @valid_fields [
    "address",
    "city",
    "date_of_birth",
    "district",
    "email",
    "full_name",
    "gender",
    "id",
    "phone",
    "pincode",
    "role",
    "state",
    "whatsapp_phone"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all user", %{conn: conn} do
      conn = get(conn, Routes.user_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "address" => "some address",
               "city" => "some city",
               "district" => "some district",
               "email" => "some email",
               "full_name" => "some full name",
               "gender" => "some gender",
               "phone" => "9456591269",
               "pincode" => "some pincode",
               "role" => "some role",
               "state" => "some state",
               "whatsapp_phone" => "some whatsapp phone"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.user_path(conn, :create), user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, Routes.user_path(conn, :update, user), @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.user_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "address" => "some updated address",
               "city" => "some updated city",
               "district" => "some updated district",
               "email" => "some updated email",
               "full_name" => "some updated full name",
               "gender" => "some updated gender",
               "phone" => "9456591269",
               "pincode" => "some updated pincode",
               "role" => "some updated role",
               "state" => "some updated state",
               "whatsapp_phone" => "some updated whatsapp phone"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.user_path(conn, :update, user), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_user(_) do
    user = user_fixture()
    %{user: user}
  end
end
