defmodule DbserviceWeb.SessionOccurrenceControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SessionsFixtures

  alias Dbservice.Sessions.SessionOccurrence

  @create_attrs %{
    end_time: ~U[2022-04-28 14:05:00Z],
    start_time: ~U[2022-04-28 14:05:00Z]
  }
  @update_attrs %{
    end_time: ~U[2022-04-29 14:05:00Z],
    start_time: ~U[2022-04-29 14:05:00Z]
  }
  @invalid_attrs %{
    end_time: nil,
    start_time: nil,
    session_id: nil
  }
  @valid_fields [
    "end_time",
    "id",
    "session_fk",
    "session_id",
    "start_time"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all session_occurrence", %{conn: conn} do
      conn = get(conn, Routes.session_occurrence_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create session_occurrence" do
    test "renders session_occurrence when data is valid", %{conn: conn} do
      conn = post(conn, Routes.session_occurrence_path(conn, :create), get_ids_create_attrs())

      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.session_occurrence_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-28T14:05:00Z",
               "start_time" => "2022-04-28T14:05:00Z"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.session_occurrence_path(conn, :create),
          session_occurrence: @invalid_attrs
        )

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
          Routes.session_occurrence_path(conn, :update, session_occurrence),
          get_ids_update_attrs()
        )

      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.session_occurrence_path(conn, :show, id))

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
          Routes.session_occurrence_path(conn, :update, session_occurrence),
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
      conn = delete(conn, Routes.session_occurrence_path(conn, :delete, session_occurrence))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.session_occurrence_path(conn, :show, session_occurrence))
      end
    end
  end

  defp create_session_occurrence(_) do
    session_occurrence = session_occurrence_fixture()
    %{session_occurrence: session_occurrence}
  end

  defp get_ids_create_attrs do
    session_occurrence_fixture = session_occurrence_fixture()
    session_id = session_occurrence_fixture.session_id
    Map.merge(@create_attrs, %{session_id: session_id})
  end

  defp get_ids_update_attrs do
    session_occurrence_fixture = session_occurrence_fixture()
    session_id = session_occurrence_fixture.session_id
    Map.merge(@update_attrs, %{session_id: session_id})
  end
end
