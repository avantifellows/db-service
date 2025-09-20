defmodule DbserviceWeb.SessionOccurrenceControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SessionOccurrenceFixtures

  alias Dbservice.Sessions.SessionOccurrence
  import Dbservice.SessionsFixtures

  @create_attrs %{
    end_time: ~U[2022-04-28 14:05:00Z],
    start_time: ~U[2022-04-28 14:05:00Z]
  }
  @update_attrs %{
    end_time: ~U[2022-04-29 14:05:00Z],
    start_time: ~U[2022-04-29 14:05:00Z],
    session_id: Ecto.UUID.generate()
  }
  @invalid_attrs %{
    end_time: nil,
    start_time: nil,
    session_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all session_occurrence and includes newly created one", %{conn: conn} do
      session_occurrence = session_occurrence_fixture()
      conn = get(conn, ~p"/api/session-occurrence")
      [head | _tail] = json_response(conn, 200)
      assert head["id"] == session_occurrence.id
      assert head["start_time"] == DateTime.to_iso8601(session_occurrence.start_time)
      assert head["end_time"] == DateTime.to_iso8601(session_occurrence.end_time)
    end
  end

  describe "create session_occurrence" do
    test "renders session_occurrence when data is valid", %{conn: conn} do
      session = session_fixture()

      attrs = Map.put(@create_attrs, :session_id, session.session_id)
      attrs = Map.put(attrs, :session_fk, session.id)

      conn = post(conn, ~p"/api/session-occurrence", attrs)

      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/session-occurrence/#{id}")
      session_id = session.session_id
      session_fk = session.id

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-28T14:05:00Z",
               "start_time" => "2022-04-28T14:05:00Z",
               "session_id" => ^session_id,
               "session_fk" => ^session_fk
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/api/session-occurrence", @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update session_occurrence" do
    setup [:create_session_occurrence]

    test "renders session_occurrence when data is valid", %{
      conn: conn,
      session_occurrence: %SessionOccurrence{id: id} = session_occurrence
    } do
      conn =
        put(
          conn,
          ~p"/api/session-occurrence/#{session_occurrence}",
          @update_attrs
        )

      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/session-occurrence/#{id}")

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-29T14:05:00Z",
               "start_time" => "2022-04-29T14:05:00Z"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      session_occurrence: session_occurrence
    } do
      conn =
        put(
          conn,
          ~p"/api/session-occurrence/#{session_occurrence}",
          @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete session_occurrence" do
    setup [:create_session_occurrence]

    test "deletes chosen session_occurrence", %{
      conn: conn,
      session_occurrence: session_occurrence
    } do
      conn = delete(conn, ~p"/api/session-occurrence/#{session_occurrence}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/session-occurrence/#{session_occurrence}")
      end
    end
  end

  defp create_session_occurrence(_) do
    session_occurrence = session_occurrence_fixture()
    %{session_occurrence: session_occurrence}
  end
end
