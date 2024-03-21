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
      target_outreach: program.target_outreach,
      donor: program.donor,
      state: program.state,
      product_id: program.product_id
    }
  end
end
