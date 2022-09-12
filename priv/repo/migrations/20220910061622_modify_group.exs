defmodule Dbservice.Repo.Migrations.ModifyGroup do
  use Ecto.Migration

  def change do
    alter table("group") do
      remove :input_schema
      remove :locale
      remove :locale_data
    end

    alter table("group") do
      add :name, :string
      add :parent_id, :integer
      add :type, :string
      add :program_type, :string
      add :program_sub_type, :string
      add :program_mode, :string
      add :program_start_date, :date
      add :program_target_outreach, :integer
      add :program_product_used, :string
      add :program_donor, :string
      add :program_state, :string
      add :batch_contact_hours_per_week, :integer
      add :group_input_schema, :map
      add :group_locale, :string
      add :group_locale_data, :map
    end
  end
end
