defmodule DbserviceWeb.ProgramView do
  use DbserviceWeb, :view

  def render("index.json", %{program: program}) do
    Enum.map(program, &program_json/1)
  end

  def render("show.json", %{program: program}) do
    program_json(program)
  end

  def program_json(program) do
    %{
      id: program.id,
      name: program.name,
      target_outreach: program.target_outreach,
      donor: program.donor,
      state: program.state,
      product_id: program.product_id,
      model: program.model,
      is_current: program.is_current
    }
  end
end
