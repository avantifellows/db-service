defmodule Dbservice.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Users` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        address: "some address",
        city: "some city",
        district: "some district",
        email: "some email",
        first_name: "some first_name",
        gender: "some gender",
        last_name: "some last_name",
        phone: "some phone",
        pincode: "some pincode",
        role: "some role",
        state: "some state"
      })
      |> Dbservice.Users.create_user()

    user
  end
end
