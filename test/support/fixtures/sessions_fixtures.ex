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
        owner_id: get_owner_id(),
        created_by_id: get_created_by_id(),
        uuid: "",
        is_active: false,
        purpose: %{},
        repeat_schedule: %{}
      })
      |> Dbservice.Sessions.create_session()

    session
  end

  @doc """
  Generate a session_occurence.
  """
  def session_occurence_fixture(attrs \\ %{}) do
    {:ok, session_occurence} =
      attrs
      |> Enum.into(%{
        end_time: ~U[2022-04-28 14:05:00Z],
        start_time: ~U[2022-04-28 14:05:00Z],
        session_id: get_session_id()
      })
      |> Dbservice.Sessions.create_session_occurence()

    session_occurence
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
    [head | _tail] = Sessions.list_session_occurence()
    session_id = head.session_id
    session_id
  end
end
