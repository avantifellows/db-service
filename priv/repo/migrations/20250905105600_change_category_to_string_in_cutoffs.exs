defmodule Dbservice.Repo.Migrations.ChangeCategoryToStringInCutoffs do
  use Ecto.Migration

  def up do
    alter table(:cutoffs) do
      modify :category, :string
    end
  end

  def down do
    alter table(:cutoffs) do
      modify :category, :integer
    end
  end
end
