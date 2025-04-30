defmodule Dbservice.SessionsTest do
  use Dbservice.DataCase

  alias Dbservice.Sessions

  describe "session" do
    alias Dbservice.Sessions.Session

    import Dbservice.SessionsFixtures
    import Dbservice.UsersFixtures

    @invalid_attrs %{
      end_time: nil,
      meta_data: nil,
      name: nil,
      portal_link: nil,
      start_time: nil,
      platform: nil,
      platform_link: nil,
      owner_id: nil,
      created_by_id: nil,
      session_id: nil,
      purpose: nil,
      repeat_schedule: nil,
      platform_id: nil,
      type: nil,
      auth_type: nil,
      signup_form: nil,
      id_generation: nil,
      redirection: nil,
      popup_form: nil,
      popup_form_id: nil,
      signup_form_id: nil
    }

    test "list_session/0 returns all session" do
      session = session_fixture()
      [head | _tail] = Sessions.list_session()
      assert Map.keys(head) == Map.keys(session)
    end

    test "get_session!/1 returns the session with given id" do
      session = session_fixture()
      assert Sessions.get_session!(session.id) == session
    end

    test "create_session/1 with valid data creates a session" do
      valid_attrs = %{
        end_time: ~U[2022-04-28 13:58:00Z],
        meta_data: %{},
        name: "some name",
        portal_link: "some portal_link",
        start_time: ~U[2022-04-28 13:58:00Z],
        platform: "some platform",
        platform_link: "some platform_link",
        owner_id: user_fixture().id,
        created_by_id: user_fixture().id,
        session_id: Ecto.UUID.generate(),
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
        popup_form_id: nil,
        is_active: false
      }

      assert {:ok, %Session{} = session} = Sessions.create_session(valid_attrs)
      assert session.end_time == ~U[2022-04-28 13:58:00Z]
      assert session.meta_data == %{}
      assert session.name == "some name"
      assert session.portal_link == "some portal_link"
      assert session.start_time == ~U[2022-04-28 13:58:00Z]
      assert session.platform == "some platform"
      assert session.platform_link == "some platform_link"
      assert session.is_active == false
      assert session.purpose == %{}
      assert session.repeat_schedule == %{}
      assert session.signup_form_id == nil
      assert session.id_generation == false
      assert session.redirection == false
      assert session.popup_form == false
      assert session.popup_form_id == nil
    end

    test "create_session/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sessions.create_session(@invalid_attrs)
    end

    test "update_session/2 with valid data updates the session" do
      session = session_fixture()

      update_attrs = %{
        end_time: ~U[2022-04-29 13:58:00Z],
        meta_data: %{},
        name: "some updated name",
        portal_link: "some updated portal_link",
        repeat_till_date: ~U[2022-04-29 13:58:00Z],
        repeat_type: "some updated repeat_type",
        start_time: ~U[2022-04-29 13:58:00Z],
        platform: "some updated platform",
        platform_link: "some updated platform_link"
      }

      assert {:ok, %Session{} = session} = Sessions.update_session(session, update_attrs)
      assert session.end_time == ~U[2022-04-29 13:58:00Z]
      assert session.meta_data == %{}
      assert session.name == "some updated name"
      assert session.portal_link == "some updated portal_link"
      assert session.start_time == ~U[2022-04-29 13:58:00Z]
      assert session.platform == "some updated platform"
    end

    test "update_session/2 with invalid data returns error changeset" do
      session = session_fixture()
      assert {:error, %Ecto.Changeset{}} = Sessions.update_session(session, @invalid_attrs)
      assert session == Sessions.get_session!(session.id)
    end

    test "delete_session/1 deletes the session" do
      session = session_fixture()
      assert {:ok, %Session{}} = Sessions.delete_session(session)
      assert_raise Ecto.NoResultsError, fn -> Sessions.get_session!(session.id) end
    end

    test "change_session/1 returns a session changeset" do
      session = session_fixture()
      assert %Ecto.Changeset{} = Sessions.change_session(session)
    end
  end

  describe "session_occurrence" do
    alias Dbservice.Sessions.SessionOccurrence

    import Dbservice.SessionsFixtures

    @invalid_attrs %{end_time: nil, start_time: nil, session_id: nil, session_fk: nil}

    test "list_session_occurrence/0 returns all session_occurrence" do
      session_occurrence = session_occurrence_fixture()
      [head | _tail] = Sessions.list_session_occurrence()
      assert Map.keys(head) == Map.keys(session_occurrence)
    end

    test "get_session_occurrence!/1 returns the session_occurrence with given id" do
      session_occurrence = session_occurrence_fixture()
      assert Sessions.get_session_occurrence!(session_occurrence.id) == session_occurrence
    end

    test "create_session_occurrence/1 with valid data creates a session_occurrence" do
      valid_attrs = %{
        end_time: ~U[2022-04-28 14:05:00Z],
        start_time: ~U[2022-04-28 14:05:00Z],
        session_id: "some_session_id",
        session_fk: session_fixture().id
      }

      assert {:ok, %SessionOccurrence{} = session_occurrence} =
               Sessions.create_session_occurrence(valid_attrs)

      assert session_occurrence.end_time == ~U[2022-04-28 14:05:00Z]
      assert session_occurrence.start_time == ~U[2022-04-28 14:05:00Z]
    end

    test "create_session_occurrence/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sessions.create_session_occurrence(@invalid_attrs)
    end

    test "update_session_occurrence/2 with valid data updates the session_occurrence" do
      session_occurrence = session_occurrence_fixture()
      update_attrs = %{end_time: ~U[2022-04-29 14:05:00Z], start_time: ~U[2022-04-29 14:05:00Z]}

      assert {:ok, %SessionOccurrence{} = session_occurrence} =
               Sessions.update_session_occurrence(session_occurrence, update_attrs)

      assert session_occurrence.end_time == ~U[2022-04-29 14:05:00Z]
      assert session_occurrence.start_time == ~U[2022-04-29 14:05:00Z]
    end

    test "update_session_occurrence/2 with invalid data returns error changeset" do
      session_occurrence = session_occurrence_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Sessions.update_session_occurrence(session_occurrence, @invalid_attrs)

      assert session_occurrence == Sessions.get_session_occurrence!(session_occurrence.id)
    end

    test "delete_session_occurrence/1 deletes the session_occurrence" do
      session_occurrence = session_occurrence_fixture()
      assert {:ok, %SessionOccurrence{}} = Sessions.delete_session_occurrence(session_occurrence)

      assert_raise Ecto.NoResultsError, fn ->
        Sessions.get_session_occurrence!(session_occurrence.id)
      end
    end

    test "change_session_occurrence/1 returns a session_occurrence changeset" do
      session_occurrence = session_occurrence_fixture()
      assert %Ecto.Changeset{} = Sessions.change_session_occurrence(session_occurrence)
    end
  end
end
