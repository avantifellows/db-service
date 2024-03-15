defmodule DbserviceWeb.EnrollmentRecordView do
  use DbserviceWeb, :view
  alias DbserviceWeb.EnrollmentRecordView

  def render("index.json", %{enrollment_record: enrollment_record}) do
    render_many(enrollment_record, EnrollmentRecordView, "enrollment_record.json")
  end

  def render("show.json", %{enrollment_record: enrollment_record}) do
    render_one(enrollment_record, EnrollmentRecordView, "enrollment_record.json")
  end

  def render("enrollment_record.json", %{enrollment_record: enrollment_record}) do
    %{
      id: enrollment_record.id,
      grade: enrollment_record.grade,
      academic_year: enrollment_record.academic_year,
      is_current: enrollment_record.is_current,
      board_medium: enrollment_record.board_medium,
      student_id: enrollment_record.student_id,
      date_of_enrollment: enrollment_record.date_of_enrollment,
      grouping_id: enrollment_record.grouping_id,
      grouping_type: enrollment_record.grouping_type
    }
  end
end
