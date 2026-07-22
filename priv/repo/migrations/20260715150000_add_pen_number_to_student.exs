defmodule Dbservice.Repo.Migrations.AddPenNumberToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :pen_number, :text
    end

    create unique_index(:student, [:pen_number],
             where: "pen_number IS NOT NULL",
             name: :student_pen_number_unique_not_null
           )
  end
end
