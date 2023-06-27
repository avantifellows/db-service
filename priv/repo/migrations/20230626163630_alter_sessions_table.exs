defmodule Dbservice.Repo.Migrations.AlterSessionsTable do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add(:number_of_fields_in_pop_form, :string)
    end
  end
end
