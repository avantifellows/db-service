defmodule Dbservice.Repo.Migrations.UpdateProgramTable do
  use Ecto.Migration

  def change do
    alter table("program") do
      remove :type
      remove :sub_type
      remove :mode
      remove :start_date
      remove :product_used
      remove :model
      remove :group_id
    end
  end
end
