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
  @valid_fields [
    "created_by_id",
    "end_time",
    "id",
    "is_active",
    "meta_data",
    "name",
    "owner_id",
    "platform",
    "platform_link",
    "portal_link",
    "purpose",
    "repeat_schedule",
    "start_time",
    "uuid"
  ]

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all session", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :index))
      [head | _tail] = json_response(conn, 200)
      assert Map.keys(head) == @valid_fields
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      conn = post(conn, Routes.session_path(conn, :create), get_ids_create_attrs())
      %{"id" => id} = json_response(conn, 201)

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
      conn = put(conn, Routes.session_path(conn, :update, session), get_ids_update_attrs())
      %{"id" => ^id} = json_response(conn, 200)

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

  defp get_ids_create_attrs do
    session_fixture = session_fixture()
    owner_id = session_fixture.owner_id
    created_by_id = session_fixture.created_by_id
    Map.merge(@create_attrs, %{owner_id: owner_id, created_by_id: created_by_id})
  end

  defp get_ids_update_attrs do
    session_fixture = session_fixture()
    owner_id = session_fixture.owner_id
    created_by_id = session_fixture.created_by_id
    Map.merge(@update_attrs, %{owner_id: owner_id, created_by_id: created_by_id})
  end
end
