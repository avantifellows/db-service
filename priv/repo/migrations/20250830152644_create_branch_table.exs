defmodule Dbservice.Repo.Migrations.CreateBranchTable do
  use Ecto.Migration

  def change do
    create table(:branch) do
      add :branch_id, :string
      add :parent_branch, :string
      add :name, :string
      add :duration, :integer

      timestamps()
    end

    create unique_index(:branch, [:branch_id])
    create index(:branch, [:name])
    create index(:branch, [:parent_branch])
  end
end
