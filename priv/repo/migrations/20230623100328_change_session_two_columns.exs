defmodule Dbservice.Repo.Migrations.ChangeSessionTwoColumns do
  use Ecto.Migration

  def change do
    alter table(:session) do
      modify :redirection, :string
      modify :pop_up_form, :string
    end
  end
end
