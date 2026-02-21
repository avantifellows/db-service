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
      session = session_fixture()
      conn = get(conn, ~p"/api/session")
      sessions = json_response(conn, 200)
      assert is_list(sessions)
      # Find our fixture session in the response
      fixture_session = Enum.find(sessions, fn s -> s["id"] == session.id end)
      assert fixture_session["name"] == session.name
      assert fixture_session["platform"] == session.platform
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

  describe "search" do
    test "returns sessions matching platform_ids", %{conn: conn} do
      # Create test sessions with specific platform_ids
      session1 = session_fixture(%{platform: "quiz", platform_id: "quiz-001"})
      session2 = session_fixture(%{platform: "quiz", platform_id: "quiz-002"})
      _session3 = session_fixture(%{platform: "quiz", platform_id: "quiz-003"})

      # Search for specific platform_ids
      conn =
        post(conn, ~p"/api/session/search", %{
          "platform" => "quiz",
          "platform_ids" => ["quiz-001", "quiz-002"]
        })

      response = json_response(conn, 200)
      assert is_list(response)
      assert length(response) == 2

      returned_platform_ids = Enum.map(response, & &1["platform_id"])
      assert session1.platform_id in returned_platform_ids
      assert session2.platform_id in returned_platform_ids
    end

    test "returns sessions matching platform filter only", %{conn: conn} do
      _quiz_session = session_fixture(%{platform: "quiz", platform_id: "quiz-filter-test"})
      _meet_session = session_fixture(%{platform: "meet", platform_id: "meet-filter-test"})

      conn = post(conn, ~p"/api/session/search", %{"platform" => "quiz"})

      response = json_response(conn, 200)
      assert is_list(response)
      # All returned sessions should have platform "quiz"
      assert Enum.all?(response, fn s -> s["platform"] == "quiz" end)
    end

    test "returns empty list for non-matching platform_ids", %{conn: conn} do
      conn =
        post(conn, ~p"/api/session/search", %{
          "platform_ids" => ["non-existent-id-1", "non-existent-id-2"]
        })

      assert json_response(conn, 200) == []
    end

    test "returns all sessions when no filters provided", %{conn: conn} do
      _session = session_fixture()

      conn = post(conn, ~p"/api/session/search", %{})

      response = json_response(conn, 200)
      assert is_list(response)
      assert response != []
    end

    test "respects limit parameter", %{conn: conn} do
      # Create multiple sessions
      Enum.each(1..5, fn i ->
        session_fixture(%{platform_id: "limit-test-#{i}"})
      end)

      conn = post(conn, ~p"/api/session/search", %{"limit" => 2})

      response = json_response(conn, 200)
      assert length(response) == 2
    end

    test "respects sort_order parameter", %{conn: conn} do
      session1 = session_fixture(%{platform_id: "sort-test-1"})
      session2 = session_fixture(%{platform_id: "sort-test-2"})

      # Test ascending order
      conn_asc =
        post(conn, ~p"/api/session/search", %{
          "platform_ids" => ["sort-test-1", "sort-test-2"],
          "sort_order" => "asc"
        })

      response_asc = json_response(conn_asc, 200)
      assert length(response_asc) == 2
      assert hd(response_asc)["id"] == session1.id

      # Test descending order
      conn_desc =
        post(conn, ~p"/api/session/search", %{
          "platform_ids" => ["sort-test-1", "sort-test-2"],
          "sort_order" => "desc"
        })

      response_desc = json_response(conn_desc, 200)
      assert length(response_desc) == 2
      assert hd(response_desc)["id"] == session2.id
    end
  end

  defp create_session(_) do
    session = session_fixture()
    %{session: session}
  end
end
