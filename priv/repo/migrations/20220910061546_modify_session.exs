defmodule Dbservice.Repo.Migrations.ModifySession do
  use Ecto.Migration

  alter table(:session) do
    remove :repeat_type
    remove :repeat_till_date
  end

  def change do
    alter table(:session) do
      add :is_active, :boolean
      add :purpose, :map
      add :repeat_schedule, :map
    end
  end
end
