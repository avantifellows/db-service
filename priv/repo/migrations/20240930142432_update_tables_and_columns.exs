defmodule Dbservice.Repo.Migrations.UpdateTablesAndColumns do
  use Ecto.Migration

  def change do
    alter table(:school) do
      remove :board_medium
    end

    alter table(:student) do
      add :school_medium, :string
    end

    alter table(:batch) do
      add :af_medium, :string
    end

    alter table(:program) do
      add :model, :string
      add :is_current, :boolean, default: true
    end
  end
end
