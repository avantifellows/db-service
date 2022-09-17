defmodule Dbservice.Repo.Migrations.DropBatch do
  use Ecto.Migration

  def change do
    drop table("batch")
  end
end
