defmodule Dbservice.Repo.Migrations.UpdateExamTables do
  use Ecto.Migration

  def change do
    alter table(:exam) do
      add :cutoff, :map

      modify :name, :string, null: false
    end

    alter table(:student_exam_record) do
      remove :rank

      add :percentile, :float
      add :all_india_rank, :integer
      add :category_rank, :integer

      modify :student_id, :integer, null: false
      modify :exam_id, :integer, null: false
      modify :date, :date, null: false
    end
  end
end
