defmodule Dbservice.Repo.Migrations.CreateImportTable do
  use Ecto.Migration

  def change do
    create table(:imports) do
      add :filename, :string
      add :status, :string
      add :type, :string
      add :total_rows, :integer
      add :processed_rows, :integer
      add :error_count, :integer
      add :error_details, {:array, :map}

      timestamps()
    end
  end
end
