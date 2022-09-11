defmodule Dbservice.Repo.Migrations.AddColumnsToUser do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :whatsapp_phone, :string
      add :date_of_birth, :date
    end

  end
end
