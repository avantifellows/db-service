defmodule Dbservice.Repo.Migrations.AlterSessionTable do
  use Ecto.Migration

  def change do
    alter table(:session) do
      add(:type, :string)
      add(:auth_type, :string)
      add(:activate_signup, :string)
      add(:id_generation, :string)
      add(:redirection, :string)
      add(:pop_up_form, :string)
    end
  end
end
