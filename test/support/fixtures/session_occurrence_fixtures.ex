defmodule Dbservice.SessionOccurrenceFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Sessions` context.
  """

  @doc """
  Generate a session_occurrence.
  """
  def session_occurrence_fixture(attrs \\ %{}) do
    session = Dbservice.SessionsFixtures.session_fixture()

    {:ok, session_occurrence} =
      attrs
      |> Enum.into(%{
        end_time: ~U[2022-04-28 14:05:00Z],
        start_time: ~U[2022-04-28 14:05:00Z],
        session_id: session.session_id,
        session_fk: session.id
      })
      |> Dbservice.Sessions.create_session_occurrence()

    session_occurrence
  end
end
