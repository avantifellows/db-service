defmodule Dbservice.Repo.Migrations.AddSystemToBatch do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add(:system, :string)
    end
  end
end
