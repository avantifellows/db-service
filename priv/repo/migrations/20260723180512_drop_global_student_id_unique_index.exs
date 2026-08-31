defmodule Dbservice.Repo.Migrations.DropGlobalStudentIdUniqueIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    drop_if_exists index(:student, [:student_id],
                     name: :student_student_id_unique_not_null,
                     concurrently: true
                   )
  end

  def down do
    create_if_not_exists unique_index(:student, [:student_id],
                           where: "student_id IS NOT NULL AND BTRIM(student_id) <> ''",
                           name: :student_student_id_unique_not_null,
                           concurrently: true
                         )
  end
end
