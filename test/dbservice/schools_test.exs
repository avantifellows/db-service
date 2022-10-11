defmodule Dbservice.SchoolsTest do
  use Dbservice.DataCase

  alias Dbservice.Schools

  describe "school" do
    alias Dbservice.Schools.School

    import Dbservice.SchoolsFixtures

    @invalid_attrs %{
      code: nil,
      name: nil,
      udise_code: nil,
      type: nil,
      category: nil,
      region: nil,
      state_code: nil,
      state: nil,
      district_code: nil,
      district: nil,
      block_code: nil,
      block_name: nil,
      board: nil,
      board_medium: nil
    }

    test "list_school/0 returns all school" do
      school = school_fixture()

      [school_list] =
        Enum.filter(
          Schools.list_school(),
          fn t -> t.code == school.code end
        )

      assert school_list.code == school.code
    end

    test "get_school!/1 returns the school with given id" do
      school = school_fixture()
      assert Schools.get_school!(school.id) == school
    end

    test "create_school/1 with valid data creates a school" do
      valid_attrs = %{
        code: "some code",
        name: "some name",
        udise_code: "some udise code",
        type: "some type",
        category: "some category",
        region: "some region",
        state_code: "some state code",
        state: "some state",
        district_code: "some district code",
        district: "some district",
        block_code: "some block code",
        block_name: "some block name",
        board: "some board",
        board_medium: "some board medium"
      }

      assert {:ok, %School{} = school} = Schools.create_school(valid_attrs)
      assert school.code == "some code"
      assert school.name == "some name"
      assert school.udise_code == "some udise code"
      assert school.type == "some type"
      assert school.category == "some category"
      assert school.region == "some region"
      assert school.state_code == "some state code"
      assert school.state == "some state"
      assert school.district_code == "some district code"
      assert school.district == "some district"
      assert school.block_code == "some block code"
      assert school.block_name == "some block name"
      assert school.board == "some board"
      assert school.board_medium == "some board medium"
    end

    test "create_school/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Schools.create_school(@invalid_attrs)
    end

    test "update_school/2 with valid data updates the school" do
      school = school_fixture()

      update_attrs = %{
        code: "some updated code",
        name: "some updated name",
        udise_code: "some updated udise code",
        type: "some updated type",
        category: "some updated category",
        region: "some updated region",
        state_code: "some updated state code",
        state: "some updated state",
        district_code: "some updated district code",
        district: "some updated district",
        block_code: "some updated block code",
        block_name: "some updated block name",
        board: "some updated board",
        board_medium: "some updated board medium"
      }

      assert {:ok, %School{} = school} = Schools.update_school(school, update_attrs)
      assert school.code == "some updated code"
      assert school.name == "some updated name"
      assert school.udise_code == "some updated udise code"
      assert school.type == "some updated type"
      assert school.category == "some updated category"
      assert school.region == "some updated region"
      assert school.state_code == "some updated state code"
      assert school.state == "some updated state"
      assert school.district_code == "some updated district code"
      assert school.district == "some updated district"
      assert school.block_code == "some updated block code"
      assert school.block_name == "some updated block name"
      assert school.board == "some updated board"
      assert school.board_medium == "some updated board medium"
    end

    test "update_school/2 with invalid data returns error changeset" do
      school = school_fixture()
      assert {:error, %Ecto.Changeset{}} = Schools.update_school(school, @invalid_attrs)
      assert school == Schools.get_school!(school.id)
    end

    test "delete_school/1 deletes the school" do
      school = school_fixture()
      assert {:ok, %School{}} = Schools.delete_school(school)
      assert_raise Ecto.NoResultsError, fn -> Schools.get_school!(school.id) end
    end

    test "change_school/1 returns a school changeset" do
      school = school_fixture()
      assert %Ecto.Changeset{} = Schools.change_school(school)
    end
  end

  describe "enrollment_record" do
    alias Dbservice.Schools.EnrollmentRecord

    import Dbservice.SchoolsFixtures

    @invalid_attrs %{
      academic_year: nil,
      grade: nil,
      is_current: false,
      board_medium: nil,
      date_of_enrollment: nil,
      student_id: nil,
      school_id: nil
    }

    test "list_enrollment_record/0 returns all enrollment_record" do
      enrollment_record = enrollment_record_fixture()

      [enrollment_record_list] =
        Enum.filter(
          Schools.list_enrollment_record(),
          fn t -> t.board_medium == enrollment_record.board_medium end
        )

      assert enrollment_record_list.board_medium == enrollment_record.board_medium
    end

    test "get_enrollment_record!/1 returns the enrollment_record with given id" do
      enrollment_record = enrollment_record_fixture()
      assert Schools.get_enrollment_record!(enrollment_record.id) == enrollment_record
    end

    test "create_enrollment_record/1 with valid data creates a enrollment_record" do
      valid_attrs = %{
        academic_year: "some academic year",
        grade: "some grade",
        is_current: true,
        board_medium: "some board medium",
        date_of_enrollment: ~U[2022-04-28 13:58:00Z],
        student_id: 92,
        school_id: 323
      }

      assert {:ok, %EnrollmentRecord{} = enrollment_record} =
               Schools.create_enrollment_record(valid_attrs)

      assert enrollment_record.academic_year == "some academic year"
      assert enrollment_record.grade == "some grade"
      assert enrollment_record.is_current == true
      assert enrollment_record.board_medium == "some board medium"
    end

    test "create_enrollment_record/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Schools.create_enrollment_record(@invalid_attrs)
    end

    test "update_enrollment_record/2 with valid data updates the enrollment_record" do
      enrollment_record = enrollment_record_fixture()

      update_attrs = %{
        academic_year: "some updated academic_year",
        grade: "some updated grade",
        is_current: false,
        board_medium: "some updated board medium",
        date_of_enrollments: ~U[2022-04-28 13:58:00Z]
      }

      assert {:ok, %EnrollmentRecord{} = enrollment_record} =
               Schools.update_enrollment_record(enrollment_record, update_attrs)

      assert enrollment_record.academic_year == "some updated academic_year"
      assert enrollment_record.grade == "some updated grade"
      assert enrollment_record.is_current == false
      assert enrollment_record.board_medium == "some updated board medium"
    end

    test "update_enrollment_record/2 with invalid data returns error changeset" do
      enrollment_record = enrollment_record_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Schools.update_enrollment_record(enrollment_record, @invalid_attrs)

      assert enrollment_record == Schools.get_enrollment_record!(enrollment_record.id)
    end

    test "delete_enrollment_record/1 deletes the enrollment_record" do
      enrollment_record = enrollment_record_fixture()
      assert {:ok, %EnrollmentRecord{}} = Schools.delete_enrollment_record(enrollment_record)

      assert_raise Ecto.NoResultsError, fn ->
        Schools.get_enrollment_record!(enrollment_record.id)
      end
    end

    test "change_enrollment_record/1 returns a enrollment_record changeset" do
      enrollment_record = enrollment_record_fixture()
      assert %Ecto.Changeset{} = Schools.change_enrollment_record(enrollment_record)
    end
  end
end
