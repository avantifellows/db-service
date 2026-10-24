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

  describe "create_or_update_school_with_user/1" do
    alias Dbservice.Schools.School
    alias Dbservice.Users
    alias Dbservice.Users.User

    @with_user_attrs %{
      "code" => "SCH_WU_001",
      "name" => "WU School",
      "af_school_category" => "Cat",
      "district_code" => "DC1",
      "district" => "District 1",
      "state_code" => "SC1",
      "state" => "State 1"
    }

    test "creates a new school together with a user" do
      assert {:ok, %School{} = school} =
               Schools.create_or_update_school_with_user(@with_user_attrs)

      assert school.code == "SCH_WU_001"
      assert is_integer(school.user_id)
      assert %User{} = Users.get_user!(school.user_id)
    end

    test "updates an existing school and backfills a user when none is linked" do
      {:ok, legacy} = Schools.create_school(@with_user_attrs)
      assert is_nil(legacy.user_id)

      assert {:ok, %School{} = updated} =
               Schools.create_or_update_school_with_user(
                 Map.put(@with_user_attrs, "name", "Renamed")
               )

      assert updated.id == legacy.id
      assert updated.name == "Renamed"
      assert is_integer(updated.user_id)
    end

    test "reuses the linked user when updating a school that already has one" do
      {:ok, created} = Schools.create_school_with_user(@with_user_attrs)

      assert {:ok, %School{} = updated} =
               Schools.create_or_update_school_with_user(
                 Map.put(@with_user_attrs, "name", "Again")
               )

      assert updated.user_id == created.user_id
    end

    test "a row the school rejects leaves no user behind" do
      user_count = Repo.aggregate(User, :count)

      assert {:error, %Ecto.Changeset{}} =
               Schools.create_or_update_school_with_user(
                 Map.put(@with_user_attrs, "principal_incharge_contact", "+91 98765 43210")
               )

      assert Repo.aggregate(User, :count) == user_count
      assert is_nil(Schools.get_school_by_code("SCH_WU_001"))
    end

    test "a rejected row leaves no user behind for a legacy school either" do
      {:ok, legacy} = Schools.create_school(@with_user_attrs)
      assert is_nil(legacy.user_id)
      user_count = Repo.aggregate(User, :count)

      assert {:error, %Ecto.Changeset{}} =
               Schools.create_or_update_school_with_user(
                 Map.put(@with_user_attrs, "school_email", "principal.example.com")
               )

      assert Repo.aggregate(User, :count) == user_count
      assert is_nil(Schools.get_school_by_code("SCH_WU_001").user_id)
    end

    test "a rejected update leaves the linked user as it was" do
      {:ok, created} = Schools.create_school_with_user(@with_user_attrs)
      user = Users.get_user!(created.user_id)

      assert {:error, %Ecto.Changeset{}} =
               Schools.create_or_update_school_with_user(
                 Map.merge(@with_user_attrs, %{
                   "first_name" => "Renamed",
                   "grades_offered" => "11,12,13"
                 })
               )

      assert Users.get_user!(created.user_id).first_name == user.first_name
      assert Schools.get_school_by_code("SCH_WU_001").name == "WU School"
    end
  end

  describe "school profile details" do
    alias Dbservice.Schools.School
    import Dbservice.SchoolsFixtures

    @profile_attrs %{
      school_email: "principal@kvrajori.edu.in",
      principal_incharge_name: "Sunita Rao",
      principal_incharge_contact: "9876543210",
      pmu_coordinator_name: "Imran Qureshi",
      pmu_coordinator_contact: "9123456780",
      school_support_status: "Supportive",
      school_residential_status: "Non-Residential",
      grades_offered: [6, 7, 8, 9, 10, 11, 12],
      school_stream: ["Science", "Commerce"],
      estimated_strength_grade_11: 48,
      estimated_strength_grade_12: 45,
      school_notes: "Principal has offered two rooms for after-school sessions."
    }

    test "update_school/2 stores every profile detail" do
      school = school_fixture()

      assert {:ok, %School{} = school} = Schools.update_school(school, @profile_attrs)

      for {field, value} <- @profile_attrs do
        assert Map.fetch!(school, field) == value
      end
    end

    test "a school created without them has them all nil" do
      school = school_fixture()

      for field <- Map.keys(@profile_attrs) do
        assert is_nil(Map.fetch!(school, field))
      end
    end

    test "grades offered are taken as a comma-separated cell or a list" do
      school = school_fixture()

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{grades_offered: " 9 , 10,11 "})

      assert school.grades_offered == [9, 10, 11]

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{grades_offered: [12, 11, 11]})

      # Deduped and sorted, so two sheets listing the same grades in a different
      # order do not read as different answers.
      assert school.grades_offered == [11, 12]
    end

    test "a blank value clears the grades, and an empty list is its own answer" do
      school = school_fixture()
      {:ok, school} = Schools.update_school(school, %{grades_offered: "6,7,8"})
      assert school.grades_offered == [6, 7, 8]

      # Sent explicitly over the API, blank clears the field - as it does for
      # every other column here. The import never sends one: a blank cell is
      # dropped from the row before the changeset sees it, which the
      # school_addition import tests cover.
      assert {:ok, %School{} = cleared} = Schools.update_school(school, %{grades_offered: "  "})
      assert is_nil(cleared.grades_offered)

      # An empty list is an answer rather than an absence: surveyed, and runs
      # none of these grades.
      assert {:ok, %School{} = none} = Schools.update_school(school, %{grades_offered: []})
      assert none.grades_offered == []
    end

    test "a grade outside 1 to 12, or one that is not a number, is rejected" do
      school = school_fixture()

      assert {:error, changeset} = Schools.update_school(school, %{grades_offered: "6,13"})
      assert errors_on(changeset).grades_offered != []

      assert {:error, changeset} = Schools.update_school(school, %{grades_offered: [0]})
      assert errors_on(changeset).grades_offered != []

      assert {:error, changeset} = Schools.update_school(school, %{grades_offered: "six,seven"})
      assert errors_on(changeset).grades_offered != []
    end

    test "streams are taken as a comma-separated cell or a list" do
      school = school_fixture()

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{school_stream: " Commerce , Science "})

      # Sorted into the canonical order, so two sheets listing the same streams
      # in a different order read as one answer.
      assert school.school_stream == ["Science", "Commerce"]

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{school_stream: ["Arts (Humanities)", "Science"]})

      assert school.school_stream == ["Science", "Arts (Humanities)"]
    end

    test "a stream typed loosely is stored in its canonical spelling" do
      school = school_fixture()

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{school_stream: "science,ARTS,humanities"})

      # "Arts" and "Humanities" are the same stream, so the duplicate collapses.
      assert school.school_stream == ["Science", "Arts (Humanities)"]
    end

    test "a stream outside the allowed set is rejected" do
      school = school_fixture()

      assert {:error, changeset} =
               Schools.update_school(school, %{school_stream: "Science,Vocational"})

      assert errors_on(changeset).school_stream != []
    end

    test "a blank value clears the streams, and an empty list is its own answer" do
      school = school_fixture()
      {:ok, school} = Schools.update_school(school, %{school_stream: "Science"})
      assert school.school_stream == ["Science"]

      assert {:ok, %School{} = cleared} = Schools.update_school(school, %{school_stream: "  "})
      assert is_nil(cleared.school_stream)

      assert {:ok, %School{} = none} = Schools.update_school(school, %{school_stream: []})
      assert none.school_stream == []
    end

    test "the database refuses a stream written around the changeset" do
      school = school_fixture()

      assert_raise Postgrex.Error, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE school SET school_stream = ARRAY['Vocational'] WHERE id = $1",
          [school.id]
        )
      end
    end

    test "a status typed in any case is stored in its canonical spelling" do
      school = school_fixture()

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{
                 school_support_status: "  non-supportive  ",
                 school_residential_status: "RESIDENTIAL"
               })

      assert school.school_support_status == "Non-Supportive"
      assert school.school_residential_status == "Residential"
    end

    test "a status outside the allowed set is rejected" do
      school = school_fixture()

      assert {:error, changeset} =
               Schools.update_school(school, %{school_support_status: "Somewhat"})

      assert "is invalid" in errors_on(changeset).school_support_status

      assert {:error, changeset} =
               Schools.update_school(school, %{school_residential_status: "Hostel"})

      assert "is invalid" in errors_on(changeset).school_residential_status
    end

    test "a contact number that is not ten plain digits is rejected" do
      school = school_fixture()

      # The last three are the same number as the fixture's, written three other ways. If
      # any of them were stored, a search for 9876543210 would no longer find this school.
      for value <- [
            "+91 98765 43210",
            "98765-43210",
            "not a number",
            "1",
            "09876543210",
            "919876543210"
          ] do
        assert {:error, changeset} =
                 Schools.update_school(school, %{principal_incharge_contact: value})

        assert errors_on(changeset).principal_incharge_contact != []
      end

      assert {:error, changeset} =
               Schools.update_school(school, %{pmu_coordinator_contact: "+919876543210"})

      assert errors_on(changeset).pmu_coordinator_contact != []
    end

    test "an email that could not reach a mailbox is rejected" do
      school = school_fixture()

      assert {:error, changeset} =
               Schools.update_school(school, %{school_email: "principal.kvrajori.edu.in"})

      assert "must be a valid email address" in errors_on(changeset).school_email
    end

    test "blanks are stored as nil rather than empty strings" do
      school = school_fixture()

      assert {:ok, %School{} = school} =
               Schools.update_school(school, %{
                 school_email: "   ",
                 principal_incharge_name: "",
                 principal_incharge_contact: "  ",
                 pmu_coordinator_name: " ",
                 pmu_coordinator_contact: "",
                 school_support_status: "  ",
                 school_residential_status: "",
                 school_notes: "   "
               })

      assert is_nil(school.school_email)
      assert is_nil(school.principal_incharge_name)
      assert is_nil(school.principal_incharge_contact)
      assert is_nil(school.pmu_coordinator_name)
      assert is_nil(school.pmu_coordinator_contact)
      assert is_nil(school.school_support_status)
      assert is_nil(school.school_residential_status)
      assert is_nil(school.school_notes)
    end

    test "an estimated strength that is negative or implausible is rejected" do
      school = school_fixture()

      assert {:error, changeset} =
               Schools.update_school(school, %{estimated_strength_grade_12: -1})

      assert errors_on(changeset).estimated_strength_grade_12 != []

      # A per-grade cell holding what looks like a district total.
      assert {:error, changeset} =
               Schools.update_school(school, %{estimated_strength_grade_11: 250_000})

      assert errors_on(changeset).estimated_strength_grade_11 != []
    end

    test "a name longer than the column is rejected rather than failing on insert" do
      school = school_fixture()

      assert {:error, changeset} =
               Schools.update_school(school, %{
                 principal_incharge_name: String.duplicate("अ", 101)
               })

      assert errors_on(changeset).principal_incharge_name != []
    end

    test "the database refuses a grade outside the range written around the changeset" do
      school = school_fixture()

      assert_raise Postgrex.Error, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE school SET grades_offered = ARRAY[13] WHERE id = $1",
          [school.id]
        )
      end
    end

    test "the database refuses a bad status written around the changeset" do
      school = school_fixture()

      # ETL and one-off SQL write to this table directly, so the allowed values
      # are a CHECK constraint and not only a changeset rule.
      assert_raise Postgrex.Error, fn ->
        Ecto.Adapters.SQL.query!(
          Repo,
          "UPDATE school SET school_support_status = 'Somewhat' WHERE id = $1",
          [school.id]
        )
      end
    end
  end
end
