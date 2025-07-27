defmodule DbserviceWeb.PurposeJSON do
  def index(%{purpose: purpose}) do
    for(p <- purpose, do: render(p))
  end

  def show(%{purpose: purpose}) do
    render(purpose)
  end

  defp render(purpose) do
    %{
      id: purpose.id,
      name: purpose.name,
      description: purpose.description
    }
  end
end
