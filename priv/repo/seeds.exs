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
alias Dbservice.Sessions

alias Faker.Person
alias Faker.Internet
alias Faker.Phone
alias Faker.Address

import Ecto.Query

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

  def create_session() do

    owner = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()
    creator = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, session} = Sessions.create_session(%{
      name: "Kendriya Vidyalaya - Weekly Maths class 7",
      platform: Enum.random(["meet", "zoom", "teams"]),
      platform_link: Enum.random(["https://meet.google.com/asl-skas-qwe", "https://meet.google.com/oep-susi-iop"]),
      portal_link: Enum.random(["https://links.af.org/kv-wmc7", "https://links.af.org/io-zmks", "https://links.af.org/po-dan"]),
      start_time: Faker.DateTime.backward(Enum.random(1..10)),
      end_time: Faker.DateTime.backward(Enum.random(1..9)),
      repeat_type: Enum.random(["weekly", "daily", "monthly"]),
      repeat_till_date: Faker.DateTime.forward(Enum.random(1..10)),
      meta_data: %{},
      owner_id: owner.id,
      created_by_id: creator.id,
      is_active: Enum.random([true, false])
    })
    session
  end

  def create_session_occurence() do
    session = Sessions.Session |> offset(^Enum.random(1..49)) |> limit(1) |> Repo.one()
    {:ok, session_occurence} = Sessions.create_session_occurence(%{
      session_id: session.id,
      start_time: session.start_time,
      end_time: session.end_time
    })
    session_occurence
  end

  def create_user_session() do
    session_occurence = Sessions.SessionOccurence |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()
    user = Users.User |> offset(^Enum.random(1..99)) |> limit(1) |> Repo.one()

    {:ok, user_session} = Sessions.create_user_session(%{
      session_occurence_id: session_occurence.id,
      user_id: user.id,
      start_time: session_occurence.start_time,
      end_time: session_occurence.end_time,
      data: %{}
    })
    user_session
  end

  def create_student() do
    {:ok, group} = Users.create_student(%{
      input_schema: %{},
      locale: Enum.random(["hi", "en"]),
      locale_data: %{}
    })
    group
  end

  def create_teacher() do
    {:ok, group} = Users.create_teacher(%{
      input_schema: %{},
      locale: Enum.random(["hi", "en"]),
      locale_data: %{}
    })
    group
  end
end

Repo.query("TRUNCATE batch_user", [])
Repo.delete_all(Batches.Batch)
Repo.delete_all(Groups.Group)
Repo.delete_all(Sessions.SessionOccurence)
Repo.delete_all(Sessions.Session)
Repo.delete_all(Users.User)

for num <- 1..10 do
  Seed.create_user()
end


if Mix.env() == :dev do
  # create some users
  for num <- 1..100 do
    Seed.create_user()
  end

  # # create some groups
  # for count <- 1..5 do
  #   group = Seed.create_group()
  # end

  # # create some batches
  # for count <- 1..10 do
  #   batch = Seed.create_batch()

  #   # create users for the batches
  #   user_ids = for num <- 1..10 do
  #     user = Seed.create_user()
  #     user.id
  #   end
  #   Batches.update_users(batch.id, user_ids)
  # end

  # create some sessions
  for count <- 1..50 do
    Seed.create_session()
  end

  # create some sessions occurences and user-session mappings
  for count <- 1..100 do
    Seed.create_session_occurence()
  end

  # create some user session-occurence mappings
  for count <- 1..200 do
    Seed.create_user_session()
  end

end
