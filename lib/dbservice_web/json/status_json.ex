defmodule DbserviceWeb.StatusJSON do
  def index(%{status: status}) do
    %{data: for(s <- status, do: data(s))}
  end

  def show(%{status: status}) do
    %{data: data(status)}
  end

  def data(status) do
    %{
      id: status.id,
      title: status.title
    }
  end
end
