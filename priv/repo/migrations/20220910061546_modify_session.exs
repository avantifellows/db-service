defmodule Dbservice.Repo.Migrations.ModifySession do
  use Ecto.Migration

  def change do
    alter table(:session) do
      remove :repeat_type
      remove :repeat_till_date
    end

    alter table(:session) do
      add :purpose, :map
      add :repeat_schedule, :map
    end
  end
end
