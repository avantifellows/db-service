defmodule Dbservice.SchoolsTest do
  use Dbservice.DataCase

  alias Dbservice.Schools

  describe "school" do
    alias Dbservice.Schools.School

    import Dbservice.SchoolsFixtures

    @invalid_attrs %{code: nil, medium: nil, name: nil}

    test "list_school/0 returns all school" do
      school = school_fixture()
      assert Schools.list_school() == [school]
    end

    test "get_school!/1 returns the school with given id" do
      school = school_fixture()
      assert Schools.get_school!(school.id) == school
    end

    test "create_school/1 with valid data creates a school" do
      valid_attrs = %{code: "some code", medium: "some medium", name: "some name"}

      assert {:ok, %School{} = school} = Schools.create_school(valid_attrs)
      assert school.code == "some code"
      assert school.medium == "some medium"
      assert school.name == "some name"
    end

    test "create_school/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Schools.create_school(@invalid_attrs)
    end

    test "update_school/2 with valid data updates the school" do
      school = school_fixture()

      update_attrs = %{
        code: "some updated code",
        medium: "some updated medium",
        name: "some updated name"
      }

      assert {:ok, %School{} = school} = Schools.update_school(school, update_attrs)
      assert school.code == "some updated code"
      assert school.medium == "some updated medium"
      assert school.name == "some updated name"
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

    @invalid_attrs %{academic_year: nil, grade: nil, is_current: nil}

    test "list_enrollment_record/0 returns all enrollment_record" do
      enrollment_record = enrollment_record_fixture()
      assert Schools.list_enrollment_record() == [enrollment_record]
    end

    test "get_enrollment_record!/1 returns the enrollment_record with given id" do
      enrollment_record = enrollment_record_fixture()
      assert Schools.get_enrollment_record!(enrollment_record.id) == enrollment_record
    end

    test "create_enrollment_record/1 with valid data creates a enrollment_record" do
      valid_attrs = %{academic_year: "some academic_year", grade: "some grade", is_current: true}

      assert {:ok, %EnrollmentRecord{} = enrollment_record} =
               Schools.create_enrollment_record(valid_attrs)

      assert enrollment_record.academic_year == "some academic_year"
      assert enrollment_record.grade == "some grade"
      assert enrollment_record.is_current == true
    end

    test "create_enrollment_record/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Schools.create_enrollment_record(@invalid_attrs)
    end

    test "update_enrollment_record/2 with valid data updates the enrollment_record" do
      enrollment_record = enrollment_record_fixture()

      update_attrs = %{
        academic_year: "some updated academic_year",
        grade: "some updated grade",
        is_current: false
      }

      assert {:ok, %EnrollmentRecord{} = enrollment_record} =
               Schools.update_enrollment_record(enrollment_record, update_attrs)

      assert enrollment_record.academic_year == "some updated academic_year"
      assert enrollment_record.grade == "some updated grade"
      assert enrollment_record.is_current == false
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
