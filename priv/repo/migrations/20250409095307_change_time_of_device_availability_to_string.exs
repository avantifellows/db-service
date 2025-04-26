defmodule Dbservice.Repo.Migrations.ChangeTimeOfDeviceAvailabilityToString do
  use Ecto.Migration

  def change do
    alter table(:student) do
      modify :time_of_device_availability, :string
    end
  end
end
