defmodule DbserviceWeb.GroupSessionJSON do
  def index(%{group_session: group_session}) do
    %{data: for(gs <- group_session, do: data(gs))}
  end

  def show(%{group_session: group_session}) do
    %{data: data(group_session)}
  end

  defp data(group_session) do
    %{
      id: group_session.id,
      group_id: group_session.group_id,
      session_id: group_session.session_id
    }
  end
end
