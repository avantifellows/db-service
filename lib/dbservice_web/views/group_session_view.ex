defmodule DbserviceWeb.GroupSessionView do
  use DbserviceWeb, :view

  def render("index.json", %{group_session: group_sessions}) do
    Enum.map(group_sessions, &group_session_json/1)
  end

  def render("show.json", %{group_session: group_session}) do
    group_session_json(group_session)
  end

  def group_session_json(%{id: id, group_id: group_id, session_id: session_id}) do
    %{
      id: id,
      group_id: group_id,
      session_id: session_id
    }
  end
end
