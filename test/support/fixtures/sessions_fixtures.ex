defmodule Dbservice.SessionsFixtures do
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
        owner_id: 129,
        created_by_id: 124,
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
        session_id: 7
      })
      |> Dbservice.Sessions.create_session_occurence()

    session_occurence
  end
end
