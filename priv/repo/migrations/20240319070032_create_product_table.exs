defmodule Dbservice.Repo.Migrations.CreateProductTable do
  use Ecto.Migration

  def change do
    create table(:product) do
      add :name, :string, null: false
      add :mode, :string
      add :model, :string
      add :tech_modules, :string
      add :type, :string
      add :led_by, :string
      add :goal, :string
      add :code, :string

      timestamps()
    end

    alter table(:program) do
      add :product_id, references(:product), null: false
    end
  end
end
