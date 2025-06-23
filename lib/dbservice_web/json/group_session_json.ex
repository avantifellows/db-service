defmodule DbserviceWeb.GroupSessionJSON do
  def index(%{group_session: group_session}) do
    for(gs <- group_session, do: render(gs))
  end

  def show(%{group_session: group_session}) do
    render(group_session)
  end

  defp render(group_session) do
    %{
      id: group_session.id,
      group_id: group_session.group_id,
      session_id: group_session.session_id
    }
  end
end
