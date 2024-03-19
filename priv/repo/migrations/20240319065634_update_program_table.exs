defmodule Dbservice.Repo.Migrations.UpdateProgramTable do
  use Ecto.Migration

  def change do
    rename table("program"), :group_id, to: :auth_group_id

    alter table("program") do
      remove :type
      remove :sub_type
      remove :mode
      remove :start_date
      remove :product_used
      remove :model
    end
  end
end
