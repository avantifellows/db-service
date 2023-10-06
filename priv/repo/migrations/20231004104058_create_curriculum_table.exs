defmodule Dbservice.Repo.Migrations.CreateCurriculumTable do
  use Ecto.Migration

  def change do
    create table(:curriculum) do
      add(:name, :string)
      add(:code, :string)
      add(:tag_id, references(:tag, on_delete: :nothing))

      timestamps()
    end
  end
end
