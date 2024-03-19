defmodule Dbservice.Repo.Migrations.UpdateEnrollmentRecord do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      add :start_date, :date
      add :end_date, :date
      add :group_id, :integer
      add :group_type, :string
      add :user_id, references(:user)

      remove :grade
      remove :student_id
      remove :board_medium
      remove :date_of_enrollment
      remove :grouping_id
      remove :grouping_type
    end
  end
end
