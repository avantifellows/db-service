defmodule Dbservice.Repo.Migrations.ModifyUser do
  use Ecto.Migration

  def change do
    alter table("user") do
      remove :first_name
      remove :last_name
    end

    alter table("user") do
      add :full_name, :string
    end
  end
end
