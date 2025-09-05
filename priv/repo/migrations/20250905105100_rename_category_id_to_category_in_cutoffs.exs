defmodule Dbservice.Repo.Migrations.RenameCategoryIdToCategoryInCutoffs do
  use Ecto.Migration

  def change do
    rename table(:cutoffs), :category_id, to: :category
  end
end
