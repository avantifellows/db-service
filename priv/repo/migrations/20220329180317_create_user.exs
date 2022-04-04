defmodule Dbservice.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:user) do
      add :first_name, :string
      add :last_name, :string
      add :email, :string
      add :phone, :string
      add :gender, :string
      add :address, :text
      add :city, :string
      add :district, :string
      add :state, :string
      add :pincode, :string
      add :role, :string

      timestamps()
    end
  end
end
