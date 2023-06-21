defmodule Dbservice.Repo.Migrations.MappingSessionFormSchema do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add(:form_schema_id, references("form_schema"))
    end
  end
end
