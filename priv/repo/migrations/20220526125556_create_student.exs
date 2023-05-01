defmodule Dbservice.Repo.Migrations.CreateStudent do
  use Ecto.Migration

  def change do
    create table(:student) do
      add :uuid, :string
      add :father_name, :string
      add :father_phone, :string
      add :mother_name, :string
      add :mother_phone, :string
      add :category, :string
      add :stream, :string
      add :user_id, references(:user, on_delete: :nothing)
      add :group_id, references(:group, on_delete: :nothing)

      timestamps()
    end

    create index(:student, [:user_id])
    create index(:student, [:group_id])
  end
end
