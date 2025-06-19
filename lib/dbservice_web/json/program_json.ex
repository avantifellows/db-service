defmodule DbserviceWeb.ProgramJSON do
  def index(%{program: program}) do
    for(p <- program, do: render(p))
  end

  def show(%{program: program}) do
    render(program)
  end

  def render(program) do
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
