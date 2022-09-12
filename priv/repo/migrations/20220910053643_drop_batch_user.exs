defmodule Dbservice.Repo.Migrations.DropBatchUser do
  use Ecto.Migration

  def change do
    drop table("batch_user")

  end
end
