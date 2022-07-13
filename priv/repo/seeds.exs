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

alias Faker.Person
alias Faker.Internet
alias Faker.Phone
alias Faker.Address

Repo.delete_all(Users.User)
Repo.delete_all(Batches.Batch)

IO.inspect(Mix.env())
if Mix.env() == :dev do
  for count <- 1..50 do
    Users.create_user(%{
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
  end

  for count <- 1..10 do
    Batches.create_batch(%{
      name: Address.city() <> " " <> "Batch"
    })
  end
end
