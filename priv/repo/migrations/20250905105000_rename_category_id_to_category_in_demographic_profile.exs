defmodule Dbservice.Repo.Migrations.RenameCategoryIdToCategoryInDemographicProfile do
  use Ecto.Migration

  def change do
    rename table(:demographic_profile), :category_id, to: :category
  end
end
