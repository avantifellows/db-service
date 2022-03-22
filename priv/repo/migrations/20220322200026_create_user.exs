defmodule Portal.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:user) do
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :phone, :string

      timestamps()
    end
  end
end
