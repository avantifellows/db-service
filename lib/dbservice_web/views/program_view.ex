defmodule DbserviceWeb.ProgramView do
  use DbserviceWeb, :view
  alias DbserviceWeb.ProgramView

  def render("index.json", %{program: program}) do
    render_many(program, ProgramView, "program.json")
  end

  def render("show.json", %{program: program}) do
    render_one(program, ProgramView, "program.json")
  end

  def render("program.json", %{program: program}) do
    %{
      id: program.id,
      name: program.name,
      program_type: program.program_type,
      program_sub_type: program.program_sub_type,
      program_mode: program.program_mode,
      program_start_date: program.program_start_date,
      program_target_outreach: program.program_target_outreach,
      program_product_used: program.program_product_used,
      program_donor: program.program_donor,
      program_state: program.program_state,
      program_model: program.program_model,
      group_id: program.group_id
    }
  end
end
