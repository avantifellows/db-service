defmodule Dbservice.Repo.Migrations.AlterFormTable do
  use Ecto.Migration

  def change do
    alter table(:form_schema) do
      add(:meta_data, :map)
    end
  end
end
