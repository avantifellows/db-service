defmodule DbserviceWeb.GroupTypeView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupTypeView

  def render("index.json", %{group_type: group_type}) do
    render_many(group_type, GroupTypeView, "group_type.json")
  end

  def render("show.json", %{group_type: group_type}) do
    render_one(group_type, GroupTypeView, "group_type.json")
  end

  def render("group_type.json", %{group_type: group_type}) do
    %{
      id: group_type.id,
      type: group_type.type,
      child_id: group_type.child_id
    }
  end
end
