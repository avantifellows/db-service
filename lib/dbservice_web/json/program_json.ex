defmodule DbserviceWeb.ProgramJSON do
  def index(%{program: program}) do
    %{data: for(p <- program, do: data(p))}
  end

  def show(%{program: program}) do
    %{data: data(program)}
  end

  def data(program) do
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
