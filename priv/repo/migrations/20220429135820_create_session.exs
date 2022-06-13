defmodule Dbservice.Repo.Migrations.CreateSession do
  use Ecto.Migration

  def change do
    create table(:session) do
      add :name, :string
      add :platform, :string
      add :platform_link, :string
      add :portal_link, :text
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :repeat_type, :string
      add :repeat_till_date, :utc_datetime
      add :meta_data, :map
      add :owner_id, references(:user, on_delete: :nothing)
      add :created_by_id, references(:user, on_delete: :nothing)

      timestamps()
    end

    create index(:session, [:owner_id])
    create index(:session, [:created_by_id])
  end
end
