defmodule DbserviceWeb.StatusJSON do
  def index(%{status: status}) do
    for(s <- status, do: render(s))
  end

  def show(%{status: status}) do
    render(status)
  end

  def render(status) do
    %{
      id: status.id,
      title: status.title
    }
  end
end
