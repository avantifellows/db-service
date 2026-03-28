defmodule DbserviceWeb.CmsStatusJSON do
  def index(%{cms_status: cms_status}) do
    for(s <- cms_status, do: render(s))
  end

  def show(%{cms_status: cms_status}) do
    render(cms_status)
  end

  def render(cms_status) do
    %{
      id: cms_status.id,
      name: cms_status.name
    }
  end
end
