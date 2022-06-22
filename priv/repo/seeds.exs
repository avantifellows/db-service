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
alias Dbservice.Batches
alias Dbservice.Batches.Batch
alias Faker.Address

import Dbservice.BatchesFixtures

Repo.delete_all(Batch)

# create some batches
# for count <- 1..50 do
batch = batch_fixture()
IO.inspect(batch)
# end
