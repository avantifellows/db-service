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
      type: program.type,
      sub_type: program.sub_type,
      mode: program.mode,
      start_date: program.start_date,
      target_outreach: program.target_outreach,
      product_used: program.product_used,
      donor: program.donor,
      state: program.state,
      model: program.model,
      group_id: program.group_id
    }
  end
end
