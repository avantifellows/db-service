defmodule DbserviceWeb.GroupSessionView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupSessionView

  def render("index.json", %{group_session: group_session}) do
    render_many(group_session, GroupSessionView, "group_session.json")
  end

  def render("show.json", %{group_session: group_session}) do
    render_one(group_session, GroupSessionView, "group_session.json")
  end

  def render("group_session.json", %{group_session: group_session}) do
    %{
      id: group_session.id,
      group_id: group_session.group_id,
      session_id: group_session.session_id
    }
  end
end
