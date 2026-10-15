defmodule Dbservice.Services.EnrollmentServiceCentreTest do
  use Dbservice.DataCase

  alias Dbservice.Centres
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Services.EnrollmentService

  import Dbservice.CentresFixtures
  import Dbservice.UsersFixtures

  defp enrollment_data(user, centre, overrides \\ %{}) do
    Map.merge(
      %{
        "enrollment_type" => "centre",
        "centre_id" => centre.id,
        "user_id" => user.id,
        "academic_year" => "2026-2027",
        "start_date" => "2026-06-01"
      },
      overrides
    )
  end

  defp centre_enrollment_records(user_id) do
    Repo.all(
      from er in EnrollmentRecord,
        where: er.user_id == ^user_id and er.group_type == "centre"
    )
  end

  describe "process_enrollment/1 with a centre" do
    setup do
      %{user: user_fixture(), centre: centre_fixture()}
    end

    test "creates the group_user and the enrollment record", %{user: user, centre: centre} do
      assert {:ok, %GroupUser{} = group_user} =
               EnrollmentService.process_enrollment(enrollment_data(user, centre))

      assert group_user.user_id == user.id
      assert group_user.group_id == Centres.get_centre_group(centre.id).id

      assert [enrollment] = centre_enrollment_records(user.id)
      assert enrollment.group_id == centre.id
      assert enrollment.group_type == "centre"
      assert enrollment.academic_year == "2026-2027"
      assert enrollment.is_current
    end

    test "re-enrolling in the same centre does not duplicate the membership", %{
      user: user,
      centre: centre
    } do
      assert {:ok, _} = EnrollmentService.process_enrollment(enrollment_data(user, centre))
      assert {:ok, _} = EnrollmentService.process_enrollment(enrollment_data(user, centre))

      group_id = Centres.get_centre_group(centre.id).id

      assert [_one] =
               Repo.all(
                 from gu in GroupUser,
                   where: gu.user_id == ^user.id and gu.group_id == ^group_id
               )

      assert [_one_enrollment] = centre_enrollment_records(user.id)
    end

    test "a student cannot be enrolled in a second centre", %{user: user, centre: centre} do
      other_centre = centre_fixture(%{name: "another centre"})

      assert {:ok, _} = EnrollmentService.process_enrollment(enrollment_data(user, centre))

      assert {:error, message} =
               EnrollmentService.process_enrollment(enrollment_data(user, other_centre))

      assert message =~ "already enrolled in a different centre"
      assert [_only_the_first] = centre_enrollment_records(user.id)
    end

    test "an unknown centre is reported, not silently skipped", %{user: user} do
      assert {:error, message} =
               EnrollmentService.process_enrollment(enrollment_data(user, %{id: -1}))

      assert message =~ "Centre not found with id: -1"
    end

    test "a centre missing its group row is reported", %{user: user, centre: centre} do
      Repo.delete!(Centres.get_centre_group(centre.id))

      assert {:error, message} =
               EnrollmentService.process_enrollment(enrollment_data(user, centre))

      assert message =~ "Centre group not found with id: #{centre.id}"
    end
  end

  describe "exclusivity backstop" do
    test "the database rejects a second current centre enrollment" do
      user = user_fixture()
      centre = centre_fixture()
      other_centre = centre_fixture(%{name: "another centre"})

      assert {:ok, _} =
               Dbservice.EnrollmentRecords.create_enrollment_record(%{
                 "user_id" => user.id,
                 "group_id" => centre.id,
                 "group_type" => "centre",
                 "academic_year" => "2026-2027",
                 "start_date" => "2026-06-01"
               })

      # Bypasses EnrollmentService entirely: the partial unique index is what
      # stops duplicates arriving through imports or direct writes.
      assert {:error, changeset} =
               Dbservice.EnrollmentRecords.create_enrollment_record(%{
                 "user_id" => user.id,
                 "group_id" => other_centre.id,
                 "group_type" => "centre",
                 "academic_year" => "2026-2027",
                 "start_date" => "2026-06-01"
               })

      assert "already has a current enrollment for this exclusive group type" in errors_on(
               changeset
             ).user_id
    end
  end
end
