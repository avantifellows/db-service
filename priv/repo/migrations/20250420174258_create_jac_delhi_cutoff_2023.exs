defmodule Dbservice.Repo.Migrations.CreateJacDelhiCutoff2023 do
  use Ecto.Migration

  def change do
    create table(:jac_delhi_cutoff_2023) do
      add :institute, :string, null: false
      add :academic_program_name, :string, null: false
      add :category, :string, null: false
      add :gender, :string, null: false
      add :defense, :boolean, null: false, default: false
      add :pwd, :boolean, null: false, default: false
      add :state, :string, null: false
      add :category_key, :string, null: false
      add :closing_rank, :integer, null: false
      timestamps()
    end
  end
end
