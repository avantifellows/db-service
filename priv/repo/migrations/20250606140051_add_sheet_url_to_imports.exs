defmodule Dbservice.Repo.Migrations.AddSheetUrlToImports do
  use Ecto.Migration

  def change do
    alter table(:imports) do
      add :sheet_url, :string
    end
  end
end
