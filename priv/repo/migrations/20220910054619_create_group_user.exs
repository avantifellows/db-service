defmodule Dbservice.Repo.Migrations.CreateGroupUser do
  use Ecto.Migration

  def change do
    create table(:group_user) do
      add :group_id, references(:group, on_delete: :nothing)
      add :user_id, references(:user, on_delete: :nothing)
      add :program_manager_id, references(:user, on_delete: :nothing)
      add :program_date_of_joining, :utc_datetime
      add :program_student_language, :string

      timestamps()
    end
  end
end
