defmodule DbserviceWeb.SessionControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SessionsFixtures

  alias Dbservice.Sessions.Session

  @create_attrs %{
    end_time: ~U[2022-04-28 13:58:00Z],
    meta_data: %{},
    name: "some name",
    portal_link: "some portal link",
    start_time: ~U[2022-04-28 13:58:00Z],
    platform: "some platform",
    platform_link: "some platform link",
    owner_id: 129,
    created_by_id: 124,
    uuid: "",
    is_active: false,
    purpose: %{},
    repeat_schedule: %{}
  }
  @update_attrs %{
    end_time: ~U[2022-04-29 13:58:00Z],
    meta_data: %{},
    name: "some updated name",
    portal_link: "some updated portal link",
    repeat_till_date: ~U[2022-04-29 13:58:00Z],
    repeat_type: "some updated repeat_type",
    start_time: ~U[2022-04-29 13:58:00Z],
    platform: "some updated platform",
    platform_link: "some updated platform link",
    owner_id: 129,
    created_by_id: 124,
    uuid: "",
    is_active: false,
    purpose: %{},
    repeat_schedule: %{}
  }
  @invalid_attrs %{
    end_time: nil,
    meta_data: nil,
    name: nil,
    portal_link: nil,
    start_time: nil,
    platform: nil,
    platform_link: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all session", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert head["platform"] == "teams"
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)

      conn = get(conn, Routes.session_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-28T13:58:00Z",
               "name" => "some name",
               "portal_link" => "some portal link",
               "platform" => "some platform",
               "platform_link" => "some platform link"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), session: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update session" do
    setup [:create_session]

    test "renders session when data is valid", %{conn: conn, session: %Session{id: id} = session} do
      conn = put(conn, Routes.session_path(conn, :update, session), @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, Routes.session_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "end_time" => "2022-04-29T13:58:00Z",
               "name" => "some updated name",
               "portal_link" => "some updated portal link",
               "platform" => "some updated platform",
               "platform_link" => "some updated platform link"
             } = json_response(conn, 200)
    end

    test "renders errors when data is invalid", %{conn: conn, session: session} do
      conn = put(conn, Routes.session_path(conn, :update, session), @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  defp create_session(_) do
    session = session_fixture()
    %{session: session}
  end
end
