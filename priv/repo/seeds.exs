# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Dbservice.Repo.insert!(%Dbservice.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Dbservice.Repo
alias Dbservice.Users
alias Dbservice.Batches
alias Dbservice.Groups

alias Faker.Person
alias Faker.Internet
alias Faker.Phone
alias Faker.Address

defmodule Seed do
  def create_user() do
    {:ok, user} = Users.create_user(%{
      first_name: Person.first_name(),
      last_name: Person.last_name(),
      email: Internet.safe_email(),
      phone: Phone.PtPt.number(),
      gender: Enum.random(["male", "female"]),
      city: Address.city(),
      state: Address.state(),
      pincode: Address.postcode(),
      role: "admin"
    })
    user
  end

  def create_batch() do
    {:ok, batch} = Batches.create_batch(%{
      name: Address.city() <> " " <> "Batch"
    })
    batch
  end

  def create_group() do
    {:ok, group} = Groups.create_group(%{
      input_schema: %{},
      locale: Enum.random(["hi", "en"]),
      locale_data: %{}
    })
    group
  end
end

Repo.query("TRUNCATE batch_user", [])
Repo.delete_all(Users.User)
Repo.delete_all(Batches.Batch)
Repo.delete_all(Groups.Group)

if Mix.env() == :dev do
  # create some groups
  for count <- 1..5 do
    group = Seed.create_group()
  end

  # create some batches
  for count <- 1..10 do
    batch = Seed.create_batch()

    # create users for the batches
    user_ids = for num <- 1..10 do
      user = Seed.create_user()
      user.id
    end
    Batches.update_users(batch.id, user_ids)
  end
end
