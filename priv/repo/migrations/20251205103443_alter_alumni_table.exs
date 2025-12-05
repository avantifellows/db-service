defmodule Dbservice.Repo.Migrations.AlterAlumniTable do
  use Ecto.Migration

  def up do
    # Remove varchar parent_branch field and add self-referencing FK
    alter table(:branch) do
      remove :parent_branch
      add :parent_branch_id, references(:branch, on_delete: :nilify_all)
    end

    # Add index for better query performance
    create index(:branch, [:parent_branch_id])

    # Add current_status column to alumni table
    alter table(:alumni) do
      add :current_status, :string
    end
  end

  def down do
    # Revert alumni changes
    alter table(:alumni) do
      remove :current_status
    end

    # Revert branch changes
    drop index(:branch, [:parent_branch_id])

    alter table(:branch) do
      remove :parent_branch_id
      add :parent_branch, :string
    end
  end
end
