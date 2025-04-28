defmodule Dbservice.SessionsFixtures do
  alias Dbservice.Sessions

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Sessions` context.
  """

  @doc """
  Generate a session.
  """
  def session_fixture(attrs \\ %{}) do
    # Create valid owner and created_by IDs (e.g., from a Users fixture)
    owner = Dbservice.UsersFixtures.user_fixture()
    created_by = Dbservice.UsersFixtures.user_fixture()

    {:ok, session} =
      attrs
      |> Enum.into(%{
        end_time: ~U[2022-04-28 13:58:00Z],
        meta_data: %{},
        name: "some name",
        portal_link: "some portal_link",
        start_time: ~U[2022-04-28 13:58:00Z],
        platform: "some platform",
        platform_link: "some platform_link",
        # Use valid owner ID
        owner_id: owner.id,
        # Use valid created_by ID
        created_by_id: created_by.id,
        # Generate a unique session ID
        session_id: Ecto.UUID.generate(),
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
      })
      |> Dbservice.Sessions.create_session()

    session
  end

  @doc """
  Generate a session_occurrence.
  """
  def session_occurrence_fixture(attrs \\ %{}) do
    {:ok, session_occurrence} =
      attrs
      |> Enum.into(%{
        end_time: ~U[2022-04-28 14:05:00Z],
        start_time: ~U[2022-04-28 14:05:00Z],
        session_id: get_session_id()
      })
      |> Dbservice.Sessions.create_session_occurrence()

    session_occurrence
  end

  def get_owner_id do
    [head | _tail] = Sessions.list_session()
    owner_id = head.owner_id
    owner_id
  end

  def get_created_by_id do
    [head | _tail] = Sessions.list_session()
    created_by_id = head.created_by_id
    created_by_id
  end

  def get_session_id do
    [head | _tail] = Sessions.list_session_occurrence()
    session_id = head.session_id
    session_id
  end
end
