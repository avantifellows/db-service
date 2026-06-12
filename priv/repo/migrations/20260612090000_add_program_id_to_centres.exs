defmodule Dbservice.Repo.Migrations.AddProgramIdToCentres do
  use Ecto.Migration

  def up do
    alter table(:centres) do
      add :program_id, references(:program, on_delete: :nothing)
    end

    create index(:centres, [:program_id])

    # Backfill from the stable Centre type codes. Matching programs by name
    # keeps the migration environment-safe (program ids are not guaranteed
    # to match across staging and production).
    execute("""
    UPDATE centres
    SET program_id = program.id
    FROM program
    WHERE program.name = 'JNV CoE'
      AND centres.type_code = 'coe'
      AND centres.program_id IS NULL
    """)

    execute("""
    UPDATE centres
    SET program_id = program.id
    FROM program
    WHERE program.name = 'JNV Nodal'
      AND centres.type_code = 'nodal'
      AND centres.program_id IS NULL
    """)
  end

  def down do
    alter table(:centres) do
      remove :program_id
    end
  end
end
