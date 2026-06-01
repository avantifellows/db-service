defmodule Dbservice.AcademicMentorshipMappingFixtures do
  @moduledoc """
  Test helpers for creating academic mentorship mapping entities.
  """

  alias Dbservice.Repo

  def user_permission_fixture(attrs \\ %{}) do
    defaults = %{
      email: "teacher-#{System.unique_integer([:positive])}@example.com",
      level: 1,
      school_codes: ["SCH001"],
      regions: [],
      read_only: false,
      role: "teacher"
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {1, [permission]} =
      Repo.insert_all(
        "user_permission",
        [
          Map.merge(merged, %{
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          })
        ],
        returning: [:id, :email]
      )

    permission
  end

  def mapping_fixture(attrs \\ %{}) do
    user = Dbservice.UsersFixtures.user_fixture()
    permission = user_permission_fixture()

    {:ok, mapping} =
      attrs
      |> Enum.into(%{
        mentor_id: permission.id,
        mentee_id: user.id,
        academic_year: "2025-2026",
        created_by: "admin@example.com"
      })
      |> Dbservice.AcademicMentorshipMappings.create_mapping()

    mapping
  end
end
