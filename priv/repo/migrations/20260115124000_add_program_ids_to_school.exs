defmodule Dbservice.Repo.Migrations.AddProgramIdsToSchool do
  use Ecto.Migration

  def up do
    alter table(:school) do
      add :program_ids, {:array, :integer}, default: []
    end

    # GIN index for efficient array queries
    create index(:school, [:program_ids], using: :gin)
  end

  def down do
    drop index(:school, [:program_ids])

    alter table(:school) do
      remove :program_ids
    end
  end
end
