defmodule DbserviceWeb.AuthGroupJSON do
  def index(%{auth_group: auth_group}) do
    for(group <- auth_group, do: render(group))
  end

  def show(%{auth_group: auth_group}) do
    render(auth_group)
  end

  def render(auth_group) do
    %{
      id: auth_group.id,
      name: auth_group.name,
      input_schema: auth_group.input_schema,
      locale: auth_group.locale,
      locale_data: auth_group.locale_data
    }
  end
end
