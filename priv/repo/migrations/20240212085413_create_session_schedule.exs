defmodule Dbservice.Repo.Migrations.CreateSessionSchedule do
  use Ecto.Migration

  def change do
    create table(:session_schedule) do
      add(:session_id, references(:session, on_delete: :nothing))
      add(:day_of_week, :string)
      add(:start_time, :time)
      add(:end_time, :time)
      add(:batch_id, references(:batch, on_delete: :nothing))

      timestamps()
    end
  end
end
