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
      academic_year: enrollment_record.academic_year,
      is_current: enrollment_record.is_current,
      start_date: enrollment_record.start_date,
      end_date: enrollment_record.end_date,
      group_id: enrollment_record.group_id,
      group_type: enrollment_record.group_type,
      user_id: enrollment_record.user_id
    }
  end
end
