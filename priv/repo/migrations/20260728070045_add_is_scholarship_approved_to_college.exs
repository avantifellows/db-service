defmodule Dbservice.Repo.Migrations.AddIsScholarshipApprovedToCollege do
  use Ecto.Migration

  def change do
    alter table(:college) do
      add :is_scholarship_approved, :boolean, default: false, null: false
    end
  end
end
