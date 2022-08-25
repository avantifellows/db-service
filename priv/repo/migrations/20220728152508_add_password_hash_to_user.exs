defmodule Dbservice.Repo.Migrations.AddPasswordHashToUser do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :password_hash, :string
      add :password_confirmation, :string
    end
  end
end
