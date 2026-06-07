defmodule Dbservice.Repo.Migrations.CreateCentreManagementTables do
  use Ecto.Migration

  def change do
    create table(:centre_option_sets) do
      add :code, :string, null: false
      add :label, :string, null: false
      add :allow_multi, :boolean, default: false, null: false
      add :sort_order, :integer, default: 0, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:centre_option_sets, [:code], name: :centre_option_sets_code_unique)

    create table(:centre_options) do
      add :option_set_id, references(:centre_option_sets, on_delete: :nothing), null: false
      add :code, :string, null: false
      add :label, :string, null: false
      add :sort_order, :integer, default: 0, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:centre_options, [:option_set_id, :code],
             name: :centre_options_option_set_code_unique
           )

    create index(:centre_options, [:option_set_id])

    create table(:centres) do
      add :name, :string, null: false
      add :school_id, references(:school, on_delete: :nothing)
      add :type_code, :string
      add :category_code, :string
      add :sub_category_code, :string
      add :stream_codes, {:array, :text}, default: fragment("'{}'::text[]"), null: false
      add :is_physical, :boolean, default: false, null: false
      add :is_active, :boolean, default: true, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create index(:centres, [:school_id])
    create index(:centres, [:type_code])
    create index(:centres, [:category_code])
    create index(:centres, [:sub_category_code])
    create index(:centres, [:stream_codes], using: :gin)
  end
end
