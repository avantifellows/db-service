defmodule DbserviceWeb.GroupView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupView

  def render("index.json", %{group: group}) do
    render_many(group, GroupView, "group.json")
  end

  def render("show.json", %{group: group}) do
    render_one(group, GroupView, "group.json")
  end

  def render("group.json", %{group: group}) do
    %{
      id: group.id,
      name: group.name,
      parent_id: group.parent_id,
      type: group.type,
      program_type: group.program_type,
      program_sub_type: group.program_sub_type,
      program_mode: group.program_mode,
      program_start_date: group.program_start_date,
      program_target_outreach: group.program_target_outreach,
      program_product_used: group.program_product_used,
      program_donor: group.program_donor,
      program_state: group.program_state,
      batch_contact_hours_per_week: group.batch_contact_hours_per_week,
      group_input_schema: group.group_input_schema,
      group_locale: group.group_locale,
      group_locale_data: group.group_locale_data,
      program_model: group.program_model,
      auth_type: group.auth_type
    }
  end
end
