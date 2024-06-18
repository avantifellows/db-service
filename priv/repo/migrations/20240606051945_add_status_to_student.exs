defmodule Dbservice.Repo.Migrations.AddStatusToStudent do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add(:status, :string, default: "registered")
    end

    execute "UPDATE student SET status = 'registered' WHERE status IS NULL"

    alter table(:student) do
      modify(:status, :string, null: false)
    end
  end
end
