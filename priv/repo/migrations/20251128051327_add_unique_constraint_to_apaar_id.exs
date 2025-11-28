defmodule Dbservice.Repo.Migrations.AddUniqueConstraintToApaarId do
  use Ecto.Migration

  def up do
    # Drop existing non-unique index if it exists
    execute "DROP INDEX IF EXISTS student_apaar_id_index"

    # Handle duplicate apaar_id values by keeping the first one (by id) and setting others to NULL
    execute """
    UPDATE student s1
    SET apaar_id = NULL
    WHERE s1.apaar_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM student s2
        WHERE s2.apaar_id = s1.apaar_id
          AND s2.id < s1.id
      )
    """

    # Create unique index
    create unique_index(:student, :apaar_id)
  end

  def down do
    # Drop unique index
    drop index(:student, [:apaar_id])

    # Recreate non-unique index
    create index(:student, [:apaar_id])
  end
end
