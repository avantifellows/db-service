defmodule DbserviceWeb.UserControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.Users.User

  @create_attrs %{
    first_name: "some first name",
    last_name: "some last name",
    address: "some address",
    city: "some city",
    country: "some country",
    district: "some district",
    email: "some email",
    gender: "Male",
    phone: "9456591269",
    pincode: "some pincode",
    role: "some role",
    state: "some state",
    whatsapp_phone: "some whatsapp phone",
    date_of_birth: ~U[2022-04-28 13:58:00Z]
  }
  @update_attrs %{
    first_name: "some updated first name",
    last_name: "some updated last name",
    address: "some updated address",
    city: "some updated city",
    country: "some updated country",
    district: "some updated district",
    email: "some updated email",
    gender: "Female",
    phone: "9456591269",
    pincode: "some updated pincode",
    role: "some updated role",
    state: "some updated state",
    whatsapp_phone: "some updated whatsapp phone",
    date_of_birth: ~U[2022-04-28 13:58:00Z]
  }
  @invalid_attrs %{
    first_name: nil,
    last_name: nil,
    email: nil,
    phone: "invalid phone number",
    gender: nil,
    address: nil,
    city: nil,
    country: nil,
    district: nil,
    state: nil,
    pincode: nil,
    role: nil,
    whatsapp_phone: nil,
    date_of_birth: nil
  }

  describe "index" do
    test "lists all user", %{conn: conn} do
      user = user_fixture()
      conn = get(conn, ~p"/api/user")

      resp = json_response(conn, 200)
      assert Enum.any?(resp, fn u -> u["id"] == user.id end)
      found_user = Enum.find(resp, fn u -> u["id"] == user.id end)
      assert found_user["first_name"] == user.first_name
      assert found_user["last_name"] == user.last_name
      assert found_user["email"] == user.email
      assert found_user["phone"] == user.phone
      assert found_user["role"] == user.role
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/user", @create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/user/#{id}")

      assert %{
               "id" => ^id,
               "address" => "some address",
               "city" => "some city",
               "district" => "some district",
               "email" => "some email",
               "first_name" => "some first name",
               "last_name" => "some last name",
               "gender" => "Male",
               "phone" => "9456591269",
               "pincode" => "some pincode",
               "role" => "some role",
               "state" => "some state",
               "whatsapp_phone" => "some whatsapp phone"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/user", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, ~p"/api/user/#{user.id}", @update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/user/#{id}")

      assert %{
               "id" => ^id,
               "address" => "some updated address",
               "city" => "some updated city",
               "district" => "some updated district",
               "email" => "some updated email",
               "first_name" => "some updated first name",
               "last_name" => "some updated last name",
               "gender" => "Female",
               "phone" => "9456591269",
               "pincode" => "some updated pincode",
               "role" => "some updated role",
               "state" => "some updated state",
               "whatsapp_phone" => "some updated whatsapp phone"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/api/user/#{user.id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/user/#{user.id}")
      assert response(conn, 204)

      # Verify user is actually deleted
      conn = get(conn, ~p"/api/user/#{user.id}")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_user(_) do
    user = user_fixture()
    %{user: user}
  end
end
