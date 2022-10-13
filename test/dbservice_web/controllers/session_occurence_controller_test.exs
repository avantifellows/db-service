defmodule DbserviceWeb.SessionOccurenceControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SessionsFixtures

  alias Dbservice.Sessions.SessionOccurence

  @create_attrs %{
    end_time: ~U[2022-04-28 14:05:00Z],
    start_time: ~U[2022-04-28 14:05:00Z]
  }
  @update_attrs %{
    end_time: ~U[2022-04-29 14:05:00Z],
    start_time: ~U[2022-04-29 14:05:00Z]
  }
  @invalid_attrs %{end_time: nil, start_time: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all session_occurence", %{conn: conn} do
      conn = get(conn, Routes.session_occurence_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert head["end_time"] == "2022-10-04T00:00:06Z"
    end
  end

  describe "create session_occurence" do
    test "renders session_occurence when data is valid", %{conn: conn} do
      conn = post(conn, Routes.session_occurence_path(conn, :create), get_ids_create_attrs())

      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.session_occurence_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-28T14:05:00Z",
               "start_time" => "2022-04-28T14:05:00Z"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.session_occurence_path(conn, :create), session_occurence: @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update session_occurence" do
    setup [:create_session_occurence]

    test "renders session_occurence when data is valid", %{
      conn: conn,
      session_occurence: %SessionOccurence{id: id} = session_occurence
    } do
      conn =
        put(
          conn,
          Routes.session_occurence_path(conn, :update, session_occurence),
          get_ids_update_attrs()
        )

      assert %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.session_occurence_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-29T14:05:00Z",
               "start_time" => "2022-04-29T14:05:00Z"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{
      conn: conn,
      session_occurence: session_occurence
    } do
      conn =
        put(conn, Routes.session_occurence_path(conn, :update, session_occurence), @invalid_attrs)

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete session_occurence" do
    setup [:create_session_occurence]

    test "deletes chosen session_occurence", %{conn: conn, session_occurence: session_occurence} do
      conn = delete(conn, Routes.session_occurence_path(conn, :delete, session_occurence))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.session_occurence_path(conn, :show, session_occurence))
      end
    end
  end

  defp create_session_occurence(_) do
    session_occurence = session_occurence_fixture()
    %{session_occurence: session_occurence}
  end

  defp get_ids_create_attrs do
    session_occurence_fixture = session_occurence_fixture()
    session_id = session_occurence_fixture.session_id
    attrs1 = Map.merge(@create_attrs, %{session_id: session_id})
    attrs1
  end

  defp get_ids_update_attrs do
    session_occurence_fixture = session_occurence_fixture()
    session_id = session_occurence_fixture.session_id
    attrs2 = Map.merge(@update_attrs, %{session_id: session_id})
    attrs2
  end
end
