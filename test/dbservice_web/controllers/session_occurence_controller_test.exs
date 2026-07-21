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
      resp = json_response(conn, 200)
      assert Enum.any?(resp, fn so -> so["id"] == session_occurrence.id end)
      found_record = Enum.find(resp, fn so -> so["id"] == session_occurrence.id end)
      assert found_record["start_time"] == DateTime.to_iso8601(session_occurrence.start_time)
      assert found_record["end_time"] == DateTime.to_iso8601(session_occurrence.end_time)
    end

    test "is_start_time=active returns active occurrences ordered by end_time ascending", %{
      conn: conn
    } do
      now = DateTime.utc_now()
      past = DateTime.add(now, -365, :day)

      # All currently active (started in the past, end in the future), inserted in an order
      # that differs from their end_time order. Anchored to `now` with fixed offsets so the
      # relative ordering stays deterministic and the fixtures never expire with the calendar.
      mid = session_occurrence_fixture(%{start_time: past, end_time: DateTime.add(now, 2, :day)})
      late = session_occurrence_fixture(%{start_time: past, end_time: DateTime.add(now, 3, :day)})
      soon = session_occurrence_fixture(%{start_time: past, end_time: DateTime.add(now, 1, :day)})

      # No limit/offset so all active rows come back; assert our three are end_time-ordered.
      conn = get(conn, ~p"/api/session-occurrence?is_start_time=active")
      ids = json_response(conn, 200) |> Enum.map(& &1["id"])

      ours = Enum.filter(ids, &(&1 in [mid.id, late.id, soon.id]))
      assert ours == [soon.id, mid.id, late.id]
    end
  end

  describe "time window filters (start_time_lte / end_time_gte)" do
    # Window under test: 2030-01-01 10:00 → 2030-01-01 23:59:59.
    # An occurrence overlaps it when start_time <= window end AND end_time >= window start.
    defp window_fixtures(_) do
      %{
        # starts later inside the window (the "test starts at 2pm" case)
        upcoming:
          session_occurrence_fixture(%{
            start_time: ~U[2030-01-01 14:00:00Z],
            end_time: ~U[2030-01-01 18:00:00Z]
          }),
        # already over before the window opens
        ended:
          session_occurrence_fixture(%{
            start_time: ~U[2030-01-01 06:00:00Z],
            end_time: ~U[2030-01-01 09:00:00Z]
          }),
        # starts after the window closes
        tomorrow:
          session_occurrence_fixture(%{
            start_time: ~U[2030-01-02 10:00:00Z],
            end_time: ~U[2030-01-02 18:00:00Z]
          }),
        # started before the window and still open (multi-day continuous)
        multiday:
          session_occurrence_fixture(%{
            start_time: ~U[2029-12-30 10:00:00Z],
            end_time: ~U[2030-01-02 18:00:00Z]
          })
      }
    end

    setup [:window_fixtures]

    test "search returns occurrences overlapping the window", %{conn: conn} = ctx do
      session_ids =
        Enum.map([ctx.upcoming, ctx.ended, ctx.tomorrow, ctx.multiday], & &1.session_id)

      conn =
        post(conn, ~p"/api/session-occurrence/search", %{
          session_ids: session_ids,
          end_time_gte: "2030-01-01T10:00:00Z",
          start_time_lte: "2030-01-01T23:59:59Z"
        })

      ids = json_response(conn, 200) |> Enum.map(& &1["id"]) |> MapSet.new()

      assert MapSet.member?(ids, ctx.upcoming.id)
      assert MapSet.member?(ids, ctx.multiday.id)
      refute MapSet.member?(ids, ctx.ended.id)
      refute MapSet.member?(ids, ctx.tomorrow.id)
    end

    test "end_time_gte alone excludes only already-ended occurrences", %{conn: conn} = ctx do
      conn = get(conn, ~p"/api/session-occurrence?end_time_gte=2030-01-01T10:00:00Z")
      ids = json_response(conn, 200) |> Enum.map(& &1["id"]) |> MapSet.new()

      assert MapSet.member?(ids, ctx.upcoming.id)
      assert MapSet.member?(ids, ctx.tomorrow.id)
      assert MapSet.member?(ids, ctx.multiday.id)
      refute MapSet.member?(ids, ctx.ended.id)
    end

    test "start_time_lte alone excludes only later-starting occurrences", %{conn: conn} = ctx do
      conn = get(conn, ~p"/api/session-occurrence?start_time_lte=2030-01-01T23:59:59Z")
      ids = json_response(conn, 200) |> Enum.map(& &1["id"]) |> MapSet.new()

      assert MapSet.member?(ids, ctx.upcoming.id)
      assert MapSet.member?(ids, ctx.ended.id)
      assert MapSet.member?(ids, ctx.multiday.id)
      refute MapSet.member?(ids, ctx.tomorrow.id)
    end

    test "invalid timestamp returns 400", %{conn: conn} do
      conn = get(conn, ~p"/api/session-occurrence?end_time_gte=not-a-date")
      assert %{"error" => _} = json_response(conn, 400)
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
