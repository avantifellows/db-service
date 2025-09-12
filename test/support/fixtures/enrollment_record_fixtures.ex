defmodule Dbservice.EnrollmentRecordFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Dbservice.EnrollmentRecords` context.
  """

  @doc """
  Generate a enrollment_record.
  """
  def enrollment_record_fixture(attrs \\ %{}) do
    # Create valid user and subject
    user = Dbservice.UsersFixtures.user_fixture()
    subject = Dbservice.SubjectsFixtures.subject_fixture()

    {:ok, enrollment_record} =
      attrs
      |> Enum.into(%{
        start_date: ~D[2022-04-28],
        end_date: ~D[2022-04-28],
        is_current: true,
        academic_year: "2022-2023",
        group_id: 1,
        group_type: "some_group",
        user_id: user.id,
        subject_id: subject.id
      })
      |> Dbservice.EnrollmentRecords.create_enrollment_record()

    enrollment_record
  end
end
