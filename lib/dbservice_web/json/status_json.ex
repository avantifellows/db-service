defmodule DbserviceWeb.StatusJSON do
  def index(%{status: status}) do
    for(s <- status, do: data(s))
  end

  def show(%{status: status}) do
    data(status)
  end

  def data(status) do
    %{
      id: status.id,
      title: status.title
    }
  end
end
