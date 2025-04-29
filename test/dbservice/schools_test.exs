defmodule Dbservice.SchoolsTest do
  use Dbservice.DataCase

  alias Hex.API.User
  alias Dbservice.Schools

  describe "school" do
    alias Dbservice.Schools.School
    alias Dbservice.Users.User
    import Dbservice.SchoolsFixtures
    import Dbservice.UsersFixtures

    @invalid_attrs %{
      code: nil,
      name: nil,
      udise_code: nil,
      gender_type: nil,
      af_school_category: nil,
      region: nil,
      state_code: nil,
      state: nil,
      district_code: nil,
      district: nil,
      block_code: nil,
      block_name: nil,
      board: nil,
      user_id: nil
    }

    test "list_school/0 returns all school" do
      school = school_fixture()
      [head | _tail] = Schools.list_school()
      assert Map.keys(Map.from_struct(head)) == Map.keys(Map.from_struct(school))
    end

    test "get_school!/1 returns the school with the given id" do
      school = school_fixture()
      fetched_school = Schools.get_school!(school.id)
      fetched_school = Repo.preload(fetched_school, [:group])
      assert school == fetched_school
    end

    test "get_school_by_code/1 returns the school with the given code" do
      school = school_fixture()
      fetched_school = Schools.get_school_by_code(school.code)
      fetched_school = Repo.preload(fetched_school, [:group])
      assert school == fetched_school
    end

    test "create_school/1 with valid data creates a school" do
      valid_attrs = %{
        code: "some code",
        name: "some name",
        udise_code: "some udise code",
        gender_type: "some gender type",
        af_school_category: "some category",
        region: "some region",
        state_code: "some state code",
        state: "some state",
        district_code: "some district code",
        district: "some district",
        block_code: "some block code",
        block_name: "some block name",
        board: "some board",
        user_id: nil
      }

      assert {:ok, %School{} = school} = Schools.create_school(valid_attrs)
      assert school.code == "some code"
      assert school.name == "some name"
      assert school.udise_code == "some udise code"
      assert school.gender_type == "some gender type"
      assert school.af_school_category == "some category"
      assert school.region == "some region"
      assert school.state_code == "some state code"
      assert school.state == "some state"
      assert school.district_code == "some district code"
      assert school.district == "some district"
      assert school.block_code == "some block code"
      assert school.block_name == "some block name"
      assert school.board == "some board"
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
        gender_type: "some updated gender type",
        af_school_category: "some updated category",
        region: "some updated region",
        state_code: "some updated state code",
        state: "some updated state",
        district_code: "some updated district code",
        district: "some updated district",
        block_code: "some updated block code",
        block_name: "some updated block name",
        board: "some updated board"
      }

      assert {:ok, %School{} = school} = Schools.update_school(school, update_attrs)
      assert school.code == "some updated code"
      assert school.name == "some updated name"
      assert school.udise_code == "some updated udise code"
      assert school.gender_type == "some updated gender type"
      assert school.af_school_category == "some updated category"
      assert school.region == "some updated region"
      assert school.state_code == "some updated state code"
      assert school.state == "some updated state"
      assert school.district_code == "some updated district code"
      assert school.district == "some updated district"
      assert school.block_code == "some updated block code"
      assert school.block_name == "some updated block name"
      assert school.board == "some updated board"
    end

    test "update_school/2 with invalid data returns error changeset" do
      school = school_fixture()
      assert {:error, %Ecto.Changeset{}} = Schools.update_school(school, @invalid_attrs)
      fetched_school = Schools.get_school!(school.id)
      fetched_school = Repo.preload(fetched_school, [:group])
      assert school == fetched_school
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

    test "get_school_by_params/1 returns a list of schools based on the given parameters" do
      # Create schools with different attributes
      school1 = school_fixture(%{state: "California", district: "Los Angeles"})
      school2 = school_fixture(%{state: "California", district: "San Francisco"})
      school3 = school_fixture(%{state: "Texas", district: "Houston"})

      # Query schools in California
      params = %{state: "California"}
      result = Schools.get_school_by_params(params)

      assert length(result) == 2
      assert Enum.any?(result, fn school -> school.id == school1.id end)
      assert Enum.any?(result, fn school -> school.id == school2.id end)

      # Query schools in Los Angeles
      params = %{state: "California", district: "Los Angeles"}
      result = Schools.get_school_by_params(params)

      assert length(result) == 1
      assert Enum.any?(result, fn school -> school.id == school1.id end)

      # Query schools in Texas
      params = %{state: "Texas"}
      result = Schools.get_school_by_params(params)

      assert length(result) == 1
      assert Enum.any?(result, fn school -> school.id == school3.id end)

      # Query with no matching parameters
      params = %{state: "Florida"}
      result = Schools.get_school_by_params(params)
      assert result == []
    end

    test "create_school_with_user/1 with valid data creates a user and a school" do
      valid_attrs = %{
        code: "some code",
        name: "some name",
        udise_code: "some udise code",
        gender_type: "some gender type",
        af_school_category: "some category",
        region: "some region",
        state_code: "some state code",
        state: "some state",
        district_code: "some district code",
        district: "some district",
        block_code: "some block code",
        block_name: "some block name",
        board: "some board",
        first_name: "John",
        last_name: "Doe",
        phone: "1234567890",
        password: "password123",
        whatsapp_phone: "some whatsapp phone",
        date_of_birth: ~D[2000-01-01],
        country: "some country"
      }

      assert {:ok, %School{} = school} = Schools.create_school_with_user(valid_attrs)
      assert school.name == "some name"
      assert school.code == "some code"
      assert school.state == "some state"
      assert school.district == "some district"

      # Fetch the user associated with the school
      user = Repo.get!(User, school.user_id)
      assert user.first_name == "John"
    end

    test "create_school_with_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Schools.create_school_with_user(@invalid_attrs)
    end

    test "update_school_with_user/3  updates a user and a school" do
      school = school_fixture()
      user = user_fixture()

      update_attrs = %{
        first_name: "Jane",
        last_name: "Smith",
        email: "jane.smith@example.com",
        name: "Updated School Name",
        code: "SCH002",
        state: "Updated State",
        district: "Updated District"
      }

      assert {:ok, %School{} = updated_school} =
               Schools.update_school_with_user(school, user, update_attrs)

      assert updated_school.name == "Updated School Name"
      assert updated_school.code == "SCH002"
      assert updated_school.state == "Updated State"
      assert updated_school.district == "Updated District"
      updated_user = Repo.get!(User, updated_school.user_id)
      assert updated_user.first_name == "Jane"
      assert updated_user.last_name == "Smith"
      assert updated_user.email == "jane.smith@example.com"
    end

    test "update_school_with_user/3 with invalid data returns error changeset" do
      school = school_fixture()
      user = user_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Schools.update_school_with_user(school, user, @invalid_attrs)
    end

    # end

    # describe "enrollment_record" do
    #   alias Dbservice.EnrollmentRecords.EnrollmentRecord

    #   import Dbservice.SchoolsFixtures

    #   @invalid_attrs %{
    #     academic_year: nil,
    #     grade: nil,
    #     is_current: false,
    #     board_medium: nil,
    #     date_of_enrollment: nil,
    #     student_id: nil,
    #     school_id: nil
    #   }

    #   test "list_enrollment_record/0 returns all enrollment_record" do
    #     enrollment_record = enrollment_record_fixture()
    #     [head | _tail] = Schools.list_enrollment_record()
    #     assert Map.keys(head) == Map.keys(enrollment_record)
    #   end

    #   test "get_enrollment_record!/1 returns the enrollment_record with given id" do
    #     enrollment_record = enrollment_record_fixture()
    #     assert Schools.get_enrollment_record!(enrollment_record.id) == enrollment_record
    #   end

    #   test "create_enrollment_record/1 with valid data creates a enrollment_record" do
    #     valid_attrs = %{
    #       academic_year: "some academic year",
    #       grade: "some grade",
    #       is_current: true,
    #       board_medium: "some board medium",
    #       date_of_enrollment: ~U[2022-04-28 13:58:00Z],
    #       student_id: get_student_id(),
    #       school_id: get_school_id()
    #     }

    #     assert {:ok, %EnrollmentRecord{} = enrollment_record} =
    #              Schools.create_enrollment_record(valid_attrs)

    #     assert enrollment_record.academic_year == "some academic year"
    #     assert enrollment_record.grade == "some grade"
    #     assert enrollment_record.is_current == true
    #     assert enrollment_record.board_medium == "some board medium"
    #   end

    #   test "create_enrollment_record/1 with invalid data returns error changeset" do
    #     assert {:error, %Ecto.Changeset{}} = Schools.create_enrollment_record(@invalid_attrs)
    #   end

    #   test "update_enrollment_record/2 with valid data updates the enrollment_record" do
    #     enrollment_record = enrollment_record_fixture()

    #     update_attrs = %{
    #       academic_year: "some updated academic_year",
    #       grade: "some updated grade",
    #       is_current: false,
    #       board_medium: "some updated board medium",
    #       date_of_enrollments: ~U[2022-04-28 13:58:00Z]
    #     }

    #     assert {:ok, %EnrollmentRecord{} = enrollment_record} =
    #              Schools.update_enrollment_record(enrollment_record, update_attrs)

    #     assert enrollment_record.academic_year == "some updated academic_year"
    #     assert enrollment_record.grade == "some updated grade"
    #     assert enrollment_record.is_current == false
    #     assert enrollment_record.board_medium == "some updated board medium"
    #   end

    #   test "update_enrollment_record/2 with invalid data returns error changeset" do
    #     enrollment_record = enrollment_record_fixture()

    #     assert {:error, %Ecto.Changeset{}} =
    #              Schools.update_enrollment_record(enrollment_record, @invalid_attrs)

    #     assert enrollment_record == Schools.get_enrollment_record!(enrollment_record.id)
    #   end

    #   test "delete_enrollment_record/1 deletes the enrollment_record" do
    #     enrollment_record = enrollment_record_fixture()
    #     assert {:ok, %EnrollmentRecord{}} = Schools.delete_enrollment_record(enrollment_record)

    #     assert_raise Ecto.NoResultsError, fn ->
    #       Schools.get_enrollment_record!(enrollment_record.id)
    #     end
    #   end

    #   test "change_enrollment_record/1 returns a enrollment_record changeset" do
    #     enrollment_record = enrollment_record_fixture()
    #     assert %Ecto.Changeset{} = Schools.change_enrollment_record(enrollment_record)
    #   end
  end
end
