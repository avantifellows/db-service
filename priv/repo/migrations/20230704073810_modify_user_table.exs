defmodule Dbservice.Repo.Migrations.ModifyUserTable do
  use Ecto.Migration

  def change do
    alter table(:user) do
      remove :full_name
      add(:first_name, :string)
      add(:last_name, :string)
      add(:middle_name, :string)
    end
  end
end
