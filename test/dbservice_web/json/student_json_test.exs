defmodule DbserviceWeb.StudentJSONTest do
  use ExUnit.Case, async: true

  alias Dbservice.Users.Student
  alias Dbservice.Users.User
  alias DbserviceWeb.StudentJSON

  test "compact student response omits the personal record" do
    student = %Student{
      id: 1,
      student_id: "S1",
      grade_id: 9,
      stream: "medical",
      category: "Gen",
      pen_number: "12345678901",
      apaar_id: "apaar-1",
      father_name: "parent",
      user: %User{id: 2, first_name: "A", last_name: "B", gender: "male", email: "a@b.com"}
    }

    compact = StudentJSON.student_user_with_compact_fields(student)

    # The fields the student-facing apps use are present...
    assert compact.student_id == "S1"
    assert compact.grade_id == 9
    assert compact.user.first_name == "A"
    # ...and the rest of the record is not exposed.
    refute Map.has_key?(compact, :pen_number)
    refute Map.has_key?(compact, :apaar_id)
    refute Map.has_key?(compact, :father_name)
    refute Map.has_key?(compact.user, :email)
  end

  test "full student response still exposes PEN" do
    student = %Student{pen_number: "12345678901", user: nil}

    assert StudentJSON.render(student).pen_number == "12345678901"
  end
end
