defmodule DbserviceWeb.GroupView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupView

  def render("index.json", %{group: group}) do
    %{data: render_many(group, GroupView, "group.json")}
  end

  def render("show.json", %{group: group}) do
    %{data: render_one(group, GroupView, "group.json")}
  end

  def render("group.json", %{group: group}) do
    %{
      id: group.id,
      input_schema: group.input_schema,
      locale: group.locale,
      locale_data: group.locale_data
    }
  end
end
