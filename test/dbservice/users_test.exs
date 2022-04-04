defmodule Dbservice.UsersTest do
  use Dbservice.DataCase

  alias Dbservice.Users

  describe "user" do
    alias Dbservice.Users.User

    import Dbservice.UsersFixtures

    @invalid_attrs %{address: nil, city: nil, district: nil, email: nil, first_name: nil, gender: nil, last_name: nil, phone: nil, pincode: nil, role: nil, state: nil}

    test "list_user/0 returns all user" do
      user = user_fixture()
      assert Users.list_user() == [user]
    end

    test "get_user!/1 returns the user with given id" do
      user = user_fixture()
      assert Users.get_user!(user.id) == user
    end

    test "create_user/1 with valid data creates a user" do
      valid_attrs = %{address: "some address", city: "some city", district: "some district", email: "some email", first_name: "some first_name", gender: "some gender", last_name: "some last_name", phone: "some phone", pincode: "some pincode", role: "some role", state: "some state"}

      assert {:ok, %User{} = user} = Users.create_user(valid_attrs)
      assert user.address == "some address"
      assert user.city == "some city"
      assert user.district == "some district"
      assert user.email == "some email"
      assert user.first_name == "some first_name"
      assert user.gender == "some gender"
      assert user.last_name == "some last_name"
      assert user.phone == "some phone"
      assert user.pincode == "some pincode"
      assert user.role == "some role"
      assert user.state == "some state"
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Users.create_user(@invalid_attrs)
    end

    test "update_user/2 with valid data updates the user" do
      user = user_fixture()
      update_attrs = %{address: "some updated address", city: "some updated city", district: "some updated district", email: "some updated email", first_name: "some updated first_name", gender: "some updated gender", last_name: "some updated last_name", phone: "some updated phone", pincode: "some updated pincode", role: "some updated role", state: "some updated state"}

      assert {:ok, %User{} = user} = Users.update_user(user, update_attrs)
      assert user.address == "some updated address"
      assert user.city == "some updated city"
      assert user.district == "some updated district"
      assert user.email == "some updated email"
      assert user.first_name == "some updated first_name"
      assert user.gender == "some updated gender"
      assert user.last_name == "some updated last_name"
      assert user.phone == "some updated phone"
      assert user.pincode == "some updated pincode"
      assert user.role == "some updated role"
      assert user.state == "some updated state"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Users.update_user(user, @invalid_attrs)
      assert user == Users.get_user!(user.id)
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Users.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Users.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Users.change_user(user)
    end
  end
end
