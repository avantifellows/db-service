defmodule Dbservice.Repo.Migrations.CreateTagTable do
  use Ecto.Migration

  def change do
    create table(:tag) do
      add(:name, :string)
      add(:description, :text)

      timestamps()
    end
  end
end
