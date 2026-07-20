defmodule DbserviceWeb.SwaggerSchema.StudentTest do
  use ExUnit.Case, async: true

  alias DbserviceWeb.SwaggerSchema.Student

  test "student schemas expose PEN" do
    assert Student.student()[:Student]["properties"]["pen_number"]["type"] == "string"

    assert Student.student_with_user()[:StudentWithUser]["properties"]["pen_number"]["type"] ==
             "string"

    assert Student.student_with_enrollments()[:StudentWithEnrollments]["properties"]["pen_number"][
             "type"
           ] == "string"
  end
end
