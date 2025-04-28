defmodule DbserviceWeb.AuthGroupView do
  use DbserviceWeb, :view
  def render("index.json", %{auth_group: auth_group}) do
    %{auth_groups: Enum.map(auth_group, &auth_group_json/1)}
  end

  def render("show.json", %{auth_group: auth_group}) do
    %{auth_group: auth_group_json(auth_group)}
  end

  def auth_group_json(%{
        id: id,
        name: name,
        input_schema: input_schema,
        locale: locale,
        locale_data: locale_data
      }) do
    %{
      id: id,
      name: name,
      input_schema: input_schema,
      locale: locale,
      locale_data: locale_data
    }
  end
end
