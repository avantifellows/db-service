defmodule Dbservice.Repo.Migrations.AddLmsStudentIngestion do
  use Ecto.Migration

  def up do
    alter table(:student) do
      add :g10_board, :string
      add :g10_roll_no, :string
    end

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT student_id
        FROM student
        WHERE student_id IS NOT NULL AND BTRIM(student_id) <> ''
        GROUP BY student_id
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'student.student_id has duplicate non-null values; resolve before adding unique index';
      END IF;

      IF EXISTS (
        SELECT apaar_id
        FROM student
        WHERE apaar_id IS NOT NULL AND BTRIM(apaar_id) <> ''
        GROUP BY apaar_id
        HAVING COUNT(*) > 1
      ) THEN
        RAISE EXCEPTION 'student.apaar_id has duplicate non-null values; resolve before adding unique index';
      END IF;
    END $$;
    """)

    create unique_index(:student, [:student_id],
             where: "student_id IS NOT NULL AND BTRIM(student_id) <> ''",
             name: :student_student_id_unique_not_null
           )

    create unique_index(:student, [:apaar_id],
             where: "apaar_id IS NOT NULL AND BTRIM(apaar_id) <> ''",
             name: :student_apaar_id_unique_not_null
           )

    create table(:lms_student_write_audits) do
      add :action, :string, null: false
      add :actor_user_id, :integer
      add :actor_email, :string
      add :actor_login_type, :string
      add :actor_role, :string
      add :school_code, :string
      add :school_udise_code, :string
      add :program_id, :integer
      add :upload_id, :string
      add :upload_filename, :string
      add :row_number, :integer
      add :row_counts, :map, null: false, default: %{}
      add :affected_identifiers, :map, null: false, default: %{}
      add :created_values, :map, null: false, default: %{}

      timestamps()
    end

    create index(:lms_student_write_audits, [:upload_id])
    create index(:lms_student_write_audits, [:school_code])
  end

  def down do
    drop_if_exists index(:lms_student_write_audits, [:school_code])
    drop_if_exists index(:lms_student_write_audits, [:upload_id])
    drop table(:lms_student_write_audits)

    drop_if_exists index(:student, [:apaar_id], name: :student_apaar_id_unique_not_null)
    drop_if_exists index(:student, [:student_id], name: :student_student_id_unique_not_null)

    alter table(:student) do
      remove :g10_roll_no
      remove :g10_board
    end
  end
end
