defmodule Dbservice.Repo.Migrations.ModifyUuidInStudent do
  use Ecto.Migration

  def change do
    rename table(:student), :uuid, to: :student_id
  end
end
