defmodule Dbservice.Repo.Migrations.ChangeGradeIdToGradeIdsInChapter do
  use Ecto.Migration

  def change do
    # First, add the new grade_ids column as an array of integers
    alter table(:chapter) do
      add(:grade_ids, {:array, :integer}, default: [])
    end

    # Copy existing grade_id values to grade_ids array
    execute("""
    UPDATE chapter
    SET grade_ids = ARRAY[grade_id]
    WHERE grade_id IS NOT NULL
    """)

    # Remove the old grade_id column
    alter table(:chapter) do
      remove(:grade_id)
    end
  end
end
