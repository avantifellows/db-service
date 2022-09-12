defmodule Dbservice.Repo.Migrations.CreateGroupStudent do
  use Ecto.Migration

  def change do
    create table(:group_student) do
      add :student_id, references(:student, on_delete: :nothing)
      add :group_id, references(:group, on_delete: :nothing)
      add :program_manager_id, references(:user, on_delete: :nothing)
      add :program_date_of_joining, :utc_datetime
      add :program_student_language, :string
    end
  end
end
