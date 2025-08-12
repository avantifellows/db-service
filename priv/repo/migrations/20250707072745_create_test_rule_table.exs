defmodule Dbservice.Repo.Migrations.CreateTestRuleTable do
  use Ecto.Migration

  def change do
    create table(:test_rule) do
      add :exam_id, references(:exam, on_delete: :nothing)
      add :test_type, :string
      add :config, :jsonb

      timestamps()
    end

    create unique_index(:test_rule, [:exam_id, :test_type])
  end
end
