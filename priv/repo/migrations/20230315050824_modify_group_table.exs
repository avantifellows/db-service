defmodule Dbservice.Repo.Migrations.ModifyGroupTable do
  use Ecto.Migration

  def change do
    alter table("group") do
      remove :name
      remove :parent_id
      remove :program_type
      remove :program_sub_type
      remove :program_mode
      remove :program_start_date
      remove :program_target_outreach
      remove :program_product_used
      remove :program_donor
      remove :program_state
      remove :batch_contact_hours_per_week
      remove :group_input_schema
      remove :group_locale
      remove :group_locale_data
    end

    alter table("group") do
      add :child_id, :integer
    end

    create index(:group, [:child_id, :type])
  end
end
