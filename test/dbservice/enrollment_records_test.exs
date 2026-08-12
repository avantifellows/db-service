defmodule Dbservice.EnrollmentRecordsTest do
  use Dbservice.DataCase

  alias Dbservice.EnrollmentRecords

  import Dbservice.UsersFixtures

  defp base_attrs(overrides) do
    Map.merge(
      %{
        "user_id" => user_fixture().id,
        "group_id" => 1,
        "group_type" => "batch",
        "start_date" => ~D[2026-04-01],
        "academic_year" => "2026-2027"
      },
      overrides
    )
  end

  describe "academic_year format validation" do
    test "accepts a canonical YYYY-YYYY academic year" do
      assert {:ok, record} = EnrollmentRecords.create_enrollment_record(base_attrs(%{}))
      assert record.academic_year == "2026-2027"
    end

    test "rejects the short YYYY-YY form (the reported '2026-27' bug)" do
      assert {:error, changeset} =
               EnrollmentRecords.create_enrollment_record(
                 base_attrs(%{"academic_year" => "2026-27"})
               )

      assert "must be in YYYY-YYYY format (e.g. 2026-2027)" in errors_on(changeset).academic_year
    end

    test "rejects other malformed academic years" do
      for bad <- ["202-2027", "2026/2027", "2026", "abcd-efgh", "2026-2027 ", "20263-2027"] do
        assert {:error, changeset} =
                 EnrollmentRecords.create_enrollment_record(base_attrs(%{"academic_year" => bad})),
               "expected #{inspect(bad)} to be rejected"

        assert Keyword.has_key?(changeset.errors, :academic_year)
      end
    end

    test "allows a nil academic_year for auth_group enrollment records" do
      attrs =
        %{}
        |> base_attrs()
        |> Map.put("group_type", "auth_group")
        |> Map.delete("academic_year")

      assert {:ok, record} = EnrollmentRecords.create_enrollment_record(attrs)
      assert record.academic_year == nil
    end

    test "update_enrollment_record rejects a malformed academic_year" do
      {:ok, record} = EnrollmentRecords.create_enrollment_record(base_attrs(%{}))

      assert {:error, changeset} =
               EnrollmentRecords.update_enrollment_record(record, %{"academic_year" => "2026-27"})

      assert "must be in YYYY-YYYY format (e.g. 2026-2027)" in errors_on(changeset).academic_year
    end
  end
end
