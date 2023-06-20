defmodule Dbservice.Repo.Migrations.AlterSessionTable do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add(:type, string)
      add(:auth_type, string)
      add(:activate_signup, boolean)
      add(:id_generation, boolean)
      add(:redirection, boolean)
      add(:pop_up_form, boolean)
    end
  end
end
