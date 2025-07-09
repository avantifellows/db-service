defmodule Dbservice.Repo.Migrations.UpdateStudentCategory do
  use Ecto.Migration

  def up do
    # Special case: Gen-EWS should become PWD-EWS
    execute("""
      UPDATE student
      SET category = 'PWD-EWS'
      WHERE physically_handicapped = true AND category = 'Gen-EWS';
    """)

    # All other categories: prepend PWD- if not already PWD-
    execute("""
      UPDATE student
      SET category = 'PWD-' || category
      WHERE physically_handicapped = true
        AND category IS NOT NULL
        AND category != ''
        AND category != 'Gen-EWS'
        AND category NOT LIKE 'PWD-%';
    """)
  end

  def down do
    # Revert PWD-EWS back to Gen-EWS only for those who were updated
    execute("""
      UPDATE student
      SET category = 'Gen-EWS'
      WHERE physically_handicapped = true AND category = 'PWD-EWS';
    """)

    # Revert PWD-<category> back to <category> for those who were updated
    execute("""
      UPDATE student
      SET category = SUBSTRING(category FROM 5)
      WHERE physically_handicapped = true AND category LIKE 'PWD-%' AND category != 'PWD-EWS';
    """)
  end
end
