defmodule DbserviceWeb.AuthGroupView do
  use DbserviceWeb, :view
  alias DbserviceWeb.AuthGroupView

  def render("index.json", %{auth_group: auth_group}) do
    render_many(auth_group, AuthGroupView, "auth_group.json")
  end

  def render("show.json", %{auth_group: auth_group}) do
    render_one(auth_group, AuthGroupView, "auth_group.json")
  end

  def render("auth_group.json", %{auth_group: auth_group}) do
    %{
      id: auth_group.id,
      name: auth_group.name,
      input_schema: auth_group.input_schema,
      locale: auth_group.locale,
      locale_data: auth_group.locale_data
    }
  end

  def render("columns.json", %{result: result}) do
    result
  end
end
