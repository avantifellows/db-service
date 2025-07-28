defmodule Dbservice.Repo.Migrations.DropSessionSchedule do
  use Ecto.Migration

  def change do
    drop table(:session_schedule)
  end
end
