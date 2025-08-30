defmodule Dbservice.Repo.Migrations.RestructureExamTable do
  use Ecto.Migration

  def change do
    # foreign key constraints removed
    alter table(:student_exam_record) do
      remove :exam_id
    end

    alter table(:test_rule) do
      remove :exam_id
    end

    # recreating exam table
    drop table(:exam)

    create table(:exam) do
      add :exam_name, :string
      add :counselling_body, :string
      add :type, :string

      timestamps()
    end

    # foreign key constraints re-added
    alter table(:student_exam_record) do
      add :exam_id, references(:exam, on_delete: :nothing)
    end

    alter table(:test_rule) do
      add :exam_id, references(:exam, on_delete: :nothing)
    end
  end
end

# the previous exam table was incorrect and has been restructured with exam (as master) and exam_occurrence (as slave)
