defmodule Dbservice.Repo.Migrations.ChangeSessionColumns do
  use Ecto.Migration

  def change do
    alter table(:session) do
      modify :activate_signup, :string
      modify :id_generation, :string
    end
  end
end
