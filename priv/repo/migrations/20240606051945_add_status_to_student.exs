defmodule Dbservice.Repo.Migrations.AddStatusToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add(:status, :string)
    end
  end
end
