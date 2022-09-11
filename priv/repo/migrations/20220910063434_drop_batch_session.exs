defmodule Dbservice.Repo.Migrations.DropBatchSession do
  use Ecto.Migration

  def change do
    drop table("batch_session")

  end
end
