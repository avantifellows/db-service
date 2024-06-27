defmodule Dbservice.Repo.Migrations.UpdateStudentStatus do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE student
    SET status = 'registered'
    WHERE status IS NULL
    AND user_id IN (
      SELECT user_id
      FROM enrollment_record
      WHERE academic_year = '2024-2025'
    )
    """)

    rename table(:enrollment_record), :group_id, to: :group_type_id
  end
end
