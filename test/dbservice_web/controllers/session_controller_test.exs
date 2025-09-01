defmodule DbserviceWeb.SessionControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.SessionsFixtures

  alias Dbservice.Sessions.Session

  @create_attrs %{
    end_time: ~U[2022-04-28 13:58:00Z],
    meta_data: %{},
    name: "some name",
    portal_link: "some portal_link",
    start_time: ~U[2022-04-28 13:58:00Z],
    platform: "some platform",
    platform_link: "some platform_link",
    session_id: "session-123",
    is_active: false,
    purpose: %{},
    repeat_schedule: %{},
    platform_id: "some_platform_id",
    type: "some_type",
    auth_type: "some_auth_type",
    signup_form: false,
    signup_form_id: nil,
    id_generation: false,
    redirection: false,
    popup_form: false,
    popup_form_id: nil
  }
  @update_attrs %{
    end_time: ~U[2022-04-29 13:58:00Z],
    meta_data: %{},
    name: "some updated name",
    portal_link: "some updated portal_link",
    start_time: ~U[2022-04-29 13:58:00Z],
    platform: "some updated platform",
    platform_link: "some updated platform_link",
    session_id: "session-456",
    is_active: true,
    purpose: %{},
    repeat_schedule: %{},
    platform_id: "some_updated_platform_id",
    type: "some_updated_type",
    auth_type: "some_updated_auth_type",
    signup_form: false,
    signup_form_id: nil,
    id_generation: true,
    redirection: true,
    popup_form: false,
    popup_form_id: nil
  }
  @invalid_attrs %{
    end_time: nil,
    meta_data: nil,
    name: nil,
    portal_link: nil,
    start_time: nil,
    platform: nil,
    platform_link: nil,
    session_id: nil,
    is_active: nil,
    purpose: nil,
    repeat_schedule: nil,
    platform_id: nil,
    type: nil,
    auth_type: nil,
    signup_form: nil,
    signup_form_id: nil,
    id_generation: nil,
    redirection: nil,
    popup_form: nil,
    popup_form_id: nil
  }

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all sessions", %{conn: conn} do
      conn = get(conn, ~p"/api/session")
      assert json_response(conn, 200) == []
    end

    test "lists all sessions with data", %{conn: conn} do
      _session = session_fixture()
      conn = get(conn, ~p"/api/session")
      [head | _tail] = json_response(conn, 200)
      assert Map.has_key?(head, "id")
      assert Map.has_key?(head, "name")
      assert Map.has_key?(head, "platform")
      assert Map.has_key?(head, "platform_link")
      assert Map.has_key?(head, "portal_link")
      assert Map.has_key?(head, "start_time")
      assert Map.has_key?(head, "end_time")
      assert Map.has_key?(head, "meta_data")
      assert Map.has_key?(head, "owner_id")
      assert Map.has_key?(head, "created_by_id")
      assert Map.has_key?(head, "is_active")
      assert Map.has_key?(head, "session_id")
      assert Map.has_key?(head, "purpose")
      assert Map.has_key?(head, "repeat_schedule")
      assert Map.has_key?(head, "platform_id")
      assert Map.has_key?(head, "type")
      assert Map.has_key?(head, "auth_type")
      assert Map.has_key?(head, "signup_form")
      assert Map.has_key?(head, "id_generation")
      assert Map.has_key?(head, "redirection")
      assert Map.has_key?(head, "popup_form")
      assert Map.has_key?(head, "signup_form_id")
      assert Map.has_key?(head, "popup_form_id")
      assert Map.has_key?(head, "inserted_at")
      assert Map.has_key?(head, "updated_at")
    end
  end

  describe "create session" do
    test "renders session when data is valid", %{conn: conn} do
      # Create users for owner_id and created_by_id
      owner = Dbservice.UsersFixtures.user_fixture()
      created_by = Dbservice.UsersFixtures.user_fixture()

      create_attrs =
        Map.merge(@create_attrs, %{
          owner_id: owner.id,
          created_by_id: created_by.id
        })

      conn = post(conn, ~p"/api/session", create_attrs)
      %{"id" => id} = json_response(conn, 201)

      conn = get(conn, ~p"/api/session/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some name",
               "platform" => "some platform",
               "platform_link" => "some platform_link",
               "portal_link" => "some portal_link",
               "session_id" => "session-123",
               "is_active" => false,
               "platform_id" => "some_platform_id",
               "type" => "some_type",
               "auth_type" => "some_auth_type",
               "signup_form" => false,
               "id_generation" => false,
               "redirection" => false,
               "popup_form" => false
             } = response

      assert response["owner_id"] == owner.id
      assert response["created_by_id"] == created_by.id
      assert Map.has_key?(response, "start_time")
      assert Map.has_key?(response, "end_time")
      assert Map.has_key?(response, "inserted_at")
      assert Map.has_key?(response, "updated_at")
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/session", @invalid_attrs)
      assert json_response(conn, 400)["error"] == "Session ID is required"
    end
  end

  describe "show session" do
    setup [:create_session]

    test "renders session", %{conn: conn, session: %Session{id: id}} do
      conn = get(conn, ~p"/api/session/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some name",
               "platform" => "some platform",
               "platform_link" => "some platform_link",
               "portal_link" => "some portal_link",
               "session_id" => _session_id,
               "is_active" => false,
               "platform_id" => "some_platform_id",
               "type" => "some_type",
               "auth_type" => "some_auth_type",
               "signup_form" => false,
               "id_generation" => false,
               "redirection" => false,
               "popup_form" => false
             } = response

      assert Map.has_key?(response, "owner_id")
      assert Map.has_key?(response, "created_by_id")
      assert Map.has_key?(response, "start_time")
      assert Map.has_key?(response, "end_time")
      assert Map.has_key?(response, "inserted_at")
      assert Map.has_key?(response, "updated_at")
    end
  end

  describe "update session" do
    setup [:create_session]

    test "renders session when data is valid", %{conn: conn, session: %Session{id: id}} do
      # Create users for owner_id and created_by_id
      owner = Dbservice.UsersFixtures.user_fixture()
      created_by = Dbservice.UsersFixtures.user_fixture()

      update_attrs =
        Map.merge(@update_attrs, %{
          owner_id: owner.id,
          created_by_id: created_by.id
        })

      conn = put(conn, ~p"/api/session/#{id}", update_attrs)
      %{"id" => ^id} = json_response(conn, 200)

      conn = get(conn, ~p"/api/session/#{id}")

      response = json_response(conn, 200)

      assert %{
               "id" => ^id,
               "name" => "some updated name",
               "platform" => "some updated platform",
               "platform_link" => "some updated platform_link",
               "portal_link" => "some updated portal_link",
               "session_id" => "session-456",
               "is_active" => true,
               "platform_id" => "some_updated_platform_id",
               "type" => "some_updated_type",
               "auth_type" => "some_updated_auth_type",
               "signup_form" => false,
               "id_generation" => true,
               "redirection" => true,
               "popup_form" => false
             } = response

      assert response["owner_id"] == owner.id
      assert response["created_by_id"] == created_by.id
      assert Map.has_key?(response, "start_time")
      assert Map.has_key?(response, "end_time")
      assert Map.has_key?(response, "inserted_at")
      assert Map.has_key?(response, "updated_at")
    end

    test "renders errors when data is invalid", %{conn: conn, session: %Session{id: id}} do
      conn = put(conn, ~p"/api/session/#{id}", @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete session" do
    setup [:create_session]

    test "deletes chosen session", %{conn: conn, session: %Session{id: id}} do
      conn = delete(conn, ~p"/api/session/#{id}")
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, ~p"/api/session/#{id}")
      end
    end
  end

  describe "update_groups" do
    setup [:create_session]

    test "updates groups for session", %{conn: conn, session: %Session{id: id}} do
      group_ids = [1, 2, 3]
      conn = post(conn, ~p"/api/session/#{id}/update-groups", %{group_ids: group_ids})
      assert %{"id" => ^id} = json_response(conn, 200)
    end
  end

  defp create_session(_) do
    session = session_fixture()
    %{session: session}
  end
end
