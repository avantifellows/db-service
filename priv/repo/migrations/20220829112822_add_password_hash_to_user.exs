defmodule Dbservice.Repo.Migrations.AddPasswordHashToUser do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add :password_hash, :string
    end

    create unique_index(:user, [:email])
  end
end
