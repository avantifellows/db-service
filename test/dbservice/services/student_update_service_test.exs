defmodule Dbservice.Services.StudentUpdateServiceTest do
  use Dbservice.DataCase

  alias Dbservice.Services.StudentUpdateService
  import Dbservice.UsersFixtures

  describe "update_student_by_student_id/2" do
    test "successfully updates student with valid student_id" do
      {_user, student} = student_fixture()

      update_params = %{
        "first_name" => "Updated First Name",
        "last_name" => "Updated Last Name",
        "category" => "OBC",
        "father_name" => "Updated Father Name"
      }

      result =
        StudentUpdateService.update_student_by_student_id(student.student_id, update_params)

      assert {:ok, updated_student} = result
      assert updated_student.student_id == student.student_id
      assert updated_student.category == "OBC"
      assert updated_student.father_name == "Updated Father Name"

      # Verify user data was also updated
      updated_user = Dbservice.Users.get_user!(student.user_id)
      assert updated_user.first_name == "Updated First Name"
      assert updated_user.last_name == "Updated Last Name"
    end

    test "returns error when student_id does not exist" do
      update_params = %{
        "first_name" => "Updated First Name",
        "category" => "OBC"
      }

      result = StudentUpdateService.update_student_by_student_id("nonexistent_id", update_params)

      assert {:error, error_message} = result
      assert String.contains?(error_message, "Student not found with ID: nonexistent_id")
    end
  end

  describe "update_student_with_user_data/2" do
    test "successfully updates student and user data" do
      {_user, student} = student_fixture()

      update_params = %{
        "first_name" => "Updated First Name",
        "last_name" => "Updated Last Name",
        "email" => "updated@example.com",
        "phone" => "9876543210",
        "category" => "ST",
        "father_name" => "Updated Father Name",
        "mother_name" => "Updated Mother Name"
      }

      result = StudentUpdateService.update_student_with_user_data(student, update_params)

      assert {:ok, updated_student} = result
      assert updated_student.category == "ST"
      assert updated_student.father_name == "Updated Father Name"
      assert updated_student.mother_name == "Updated Mother Name"

      # Verify user data was also updated
      updated_user = Dbservice.Users.get_user!(student.user_id)
      assert updated_user.first_name == "Updated First Name"
      assert updated_user.last_name == "Updated Last Name"
      assert updated_user.email == "updated@example.com"
      assert updated_user.phone == "9876543210"
    end

    test "only updates provided fields and ignores nil/empty values" do
      {user, student} = student_fixture()
      original_email = user.email
      original_category = student.category
      original_father_name = student.father_name

      update_params = %{
        "first_name" => "Updated First Name",
        "email" => nil,
        "phone" => "",
        "category" => nil,
        "father_name" => "",
        "last_name" => "Updated Last Name"
      }

      result = StudentUpdateService.update_student_with_user_data(student, update_params)

      assert {:ok, updated_student} = result
      # Only non-nil/non-empty fields should be updated
      assert updated_student.category == original_category
      assert updated_student.father_name == original_father_name

      # Verify user data was updated for non-nil fields only
      updated_user = Dbservice.Users.get_user!(student.user_id)
      assert updated_user.first_name == "Updated First Name"
      assert updated_user.last_name == "Updated Last Name"
      # Should remain unchanged
      assert updated_user.email == original_email
    end

    test "handles empty params map without errors" do
      {user, student} = student_fixture()
      original_first_name = user.first_name
      original_category = student.category

      result = StudentUpdateService.update_student_with_user_data(student, %{})

      assert {:ok, updated_student} = result
      assert updated_student.student_id == student.student_id
      assert updated_student.category == original_category

      # Verify user data remains unchanged
      updated_user = Dbservice.Users.get_user!(student.user_id)
      assert updated_user.first_name == original_first_name
    end
  end

  describe "update_student_with_user_data/2 duplicate identifier validation (issue #641)" do
    alias Dbservice.Users

    test "rejects a row that moves another student's apaar_id onto this student" do
      {_u1, target} = student_fixture(%{student_id: "TARGET-641", apaar_id: "111111111111"})
      {_u2, other} = student_fixture(%{student_id: "OTHER-641", apaar_id: "222222222222"})

      result =
        StudentUpdateService.update_student_with_user_data(target, %{
          "apaar_id" => "222222222222",
          "first_name" => "ShouldNotApply"
        })

      assert {:error, message} = result
      assert message =~ "APAAR ID '222222222222' already exists for another student"

      # The conflicting student keeps its APAAR ID; the target is not overwritten.
      assert Users.get_student!(other.id).apaar_id == "222222222222"
      assert Users.get_student!(target.id).apaar_id == "111111111111"
      assert Users.get_user!(target.user_id).first_name != "ShouldNotApply"
    end

    test "rejects a row that moves another student's pen_number onto this student" do
      {_u1, target} = student_fixture(%{student_id: "TARGET-PEN", pen_number: "12345678901"})
      {_u2, _other} = student_fixture(%{student_id: "OTHER-PEN", pen_number: "19999999999"})

      result =
        StudentUpdateService.update_student_with_user_data(target, %{
          "pen_number" => "19999999999"
        })

      assert {:error, message} = result
      assert message =~ "PEN Number '19999999999' already exists for another student"
      assert Users.get_student!(target.id).pen_number == "12345678901"
    end

    test "allows re-saving the student's own identifiers alongside other updates" do
      {_u, target} =
        student_fixture(%{
          student_id: "TARGET-SELF",
          apaar_id: "333333333333",
          pen_number: "13333333333"
        })

      result =
        StudentUpdateService.update_student_with_user_data(target, %{
          "apaar_id" => "333333333333",
          "pen_number" => "13333333333",
          "first_name" => "Renamed"
        })

      assert {:ok, updated} = result
      assert updated.apaar_id == "333333333333"
      assert Users.get_user!(target.user_id).first_name == "Renamed"
    end

    test "allows assigning a brand new, non-conflicting apaar_id" do
      {_u, target} = student_fixture(%{student_id: "TARGET-NEW"})

      result =
        StudentUpdateService.update_student_with_user_data(target, %{"apaar_id" => "444444444444"})

      assert {:ok, updated} = result
      assert updated.apaar_id == "444444444444"
    end
  end
end
