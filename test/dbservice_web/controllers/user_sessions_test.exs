defmodule DbserviceWeb.UserSessionsTest do
  @moduledoc """
  GET /api/user/:user_id/sessions — live sessions come only from the user's
  direct batch groups; quiz sessions come from every batch in the hierarchy
  above them, filtered by the session's meta_data batch_id.
  """
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures
  import Dbservice.BatchesFixtures
  import Dbservice.GroupsFixtures
  import Dbservice.SessionsFixtures

  alias Dbservice.GroupSessions
  alias Dbservice.GroupUsers

  setup do
    user = user_fixture()

    # grandparent -> parent -> class batch the user is in; plus an unrelated batch
    grandparent = batch_fixture(%{batch_id: "GP1", name: "grandparent"})
    parent = batch_fixture(%{batch_id: "P1", name: "parent", parent_id: grandparent.id})
    class = batch_fixture(%{batch_id: "C1", name: "class", parent_id: parent.id})
    other = batch_fixture(%{batch_id: "O1", name: "other"})

    g_grandparent = group_fixture(%{type: "batch", child_id: grandparent.id})
    g_parent = group_fixture(%{type: "batch", child_id: parent.id})
    g_class = group_fixture(%{type: "batch", child_id: class.id})
    g_other = group_fixture(%{type: "batch", child_id: other.id})
    g_school = group_fixture(%{type: "school", child_id: class.id})

    {:ok, _} = GroupUsers.create_group_user(%{user_id: user.id, group_id: g_class.id})
    {:ok, _} = GroupUsers.create_group_user(%{user_id: user.id, group_id: g_school.id})

    link = fn group, attrs ->
      session = session_fixture(Map.merge(%{is_active: true}, attrs))
      {:ok, _} = GroupSessions.create_group_session(%{group_id: group.id, session_id: session.id})
      session
    end

    sessions = %{
      class_live: link.(g_class, %{name: "class live", platform: "meet"}),
      class_inactive: link.(g_class, %{name: "class inactive", is_active: false}),
      parent_quiz: link.(g_parent, %{platform: "quiz", meta_data: %{"batch_id" => "C1"}}),
      parent_quiz_wrong_batch:
        link.(g_parent, %{platform: "quiz", meta_data: %{"batch_id" => "ZZ9"}}),
      grandparent_quiz_any:
        link.(g_grandparent, %{platform: "quiz", meta_data: %{"batch_id" => ""}}),
      parent_live: link.(g_parent, %{platform: "meet"}),
      other_batch: link.(g_other, %{platform: "meet"}),
      school_group: link.(g_school, %{platform: "meet"})
    }

    %{user: user, sessions: sessions}
  end

  defp ids(conn), do: conn |> json_response(200) |> Enum.map(& &1["id"]) |> Enum.sort()

  defp expected(sessions, keys), do: keys |> Enum.map(&sessions[&1].id) |> Enum.sort()

  test "live sessions come only from the user's direct batch groups", %{
    conn: conn,
    user: user,
    sessions: s
  } do
    conn = get(conn, ~p"/api/user/#{user.id}/sessions")
    assert ids(conn) == expected(s, [:class_live])
  end

  test "quiz sessions span the whole batch hierarchy, filtered by batch_id", %{
    conn: conn,
    user: user,
    sessions: s
  } do
    conn = get(conn, ~p"/api/user/#{user.id}/sessions?quiz=true")

    assert ids(conn) ==
             expected(s, [:class_live, :parent_quiz, :grandparent_quiz_any, :parent_live])
  end

  test "a user in no batch group gets no sessions", %{conn: conn} do
    loner = user_fixture()
    assert conn |> get(~p"/api/user/#{loner.id}/sessions") |> json_response(200) == []
    assert conn |> get(~p"/api/user/#{loner.id}/sessions?quiz=true") |> json_response(200) == []
  end
end
