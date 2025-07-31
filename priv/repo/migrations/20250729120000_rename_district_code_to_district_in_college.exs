defmodule Dbservice.Repo.Migrations.RenameDistrictCodeToDistrictInCollege do
  use Ecto.Migration

  def change do
    rename table(:college), :district_code, to: :district
  end
end
