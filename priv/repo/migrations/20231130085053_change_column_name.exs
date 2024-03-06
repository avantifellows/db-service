defmodule Dbservice.Repo.Migrations.ChangeColumnName do
  use Ecto.Migration

  def change do
    rename table(:teacher), :uuid, to: :teacher_id
  end
end
