defmodule DbserviceWeb.StudentJSONTest do
  use ExUnit.Case, async: true

  alias Dbservice.Users.Student
  alias DbserviceWeb.StudentJSON

  test "compact student response exposes PEN" do
    student = %Student{pen_number: "12345678901", user: nil}

    assert StudentJSON.student_user_with_compact_fields(student).pen_number == "12345678901"
  end
end
