defmodule Dbservice.Repo.Migrations.AddColumnsToEnrollmentRecord do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      add :board_medium, :string
      add :date_of_enrollment, :date
    end
  end
end
