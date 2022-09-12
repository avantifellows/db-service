defmodule Dbservice.Repo.Migrations.ModifySchool do
  use Ecto.Migration

  def change do
    alter table(:school) do
      remove :medium
    end

    alter table(:school) do
      add :udise_code, :string
      add :type, :string
      add :category, :string
      add :region, :string
      add :state_code, :string
      add :state, :string
      add :district_code, :string
      add :district, :string
      add :block_code, :string
      add :block_name, :string
      add :board, :string
      add :board_medium, :string
    end

  end
end
