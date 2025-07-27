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
      add :start_row, :integer, default: 2, null: false
      add :completed_at, :utc_datetime

      timestamps()
    end
  end
end
