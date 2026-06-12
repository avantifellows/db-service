defmodule Dbservice.Repo.Migrations.MakeTeacherIdOptionalAndUnique do
  use Ecto.Migration

  def up do
    # "Not Permanent" is a placeholder meaning "no code"; NULL expresses that
    # now that teacher_id is optional, and clears the way for the unique index.
    execute("UPDATE teacher SET teacher_id = NULL WHERE teacher_id = 'Not Permanent'")

    alter table(:teacher) do
      add :exit_date, :date
    end

    # teacher_id is the Gurukul/Portal login identifier; admin-entered codes
    # must never collide. NULLs (code not yet assigned) are exempt. The
    # unique index supersedes the plain lookup index from 20250825075810.
    drop index(:teacher, [:teacher_id])
    create unique_index(:teacher, [:teacher_id], name: :teacher_teacher_id_unique)
  end

  def down do
    drop index(:teacher, [:teacher_id], name: :teacher_teacher_id_unique)
    create index(:teacher, [:teacher_id])

    alter table(:teacher) do
      remove :exit_date
    end
  end
end
