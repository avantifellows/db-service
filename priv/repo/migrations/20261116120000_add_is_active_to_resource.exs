defmodule Dbservice.Repo.Migrations.AddIsActiveToResource do
  use Ecto.Migration

  # Chapter content gets refreshed each year. Replacing a resource's link in
  # place leaves older BigQuery rows pointing at a quiz id whose content has
  # since changed, so a refresh now adds a row and retires the old one instead.
  # Everything that exists today is what Gurukul shows today, hence the default.
  def up do
    alter table(:resource) do
      add(:is_active, :boolean, null: false, default: true)
    end

    # Gurukul reads a chapter's resources filtered by curriculum, and will now
    # ask only for the active ones.
    create(index(:resource, [:is_active]))
  end

  def down do
    drop(index(:resource, [:is_active]))

    alter table(:resource) do
      remove(:is_active)
    end
  end
end
