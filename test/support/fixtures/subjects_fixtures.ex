defmodule Dbservice.SubjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.Subjects.Subject` schema.
  """
  alias Dbservice.Subjects

  @doc """
  Generate a subject fixture.
  """
  def subject_fixture(attrs \\ %{}) do
    default_attrs = %{
      name: "Default Subject Name",
      code: "SUB123",
      tag_id: nil
    }

    {:ok, subject} =
      attrs
      |> Enum.into(default_attrs)
      |> Subjects.create_subject()

    subject
  end
end
