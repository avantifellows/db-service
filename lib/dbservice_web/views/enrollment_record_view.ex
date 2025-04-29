defmodule DbserviceWeb.EnrollmentRecordView do
  use DbserviceWeb, :view

  def render("index.json", %{enrollment_record: enrollment_record}) do
    Enum.map(enrollment_record, &enrollment_record_json/1)
  end

  def render("show.json", %{enrollment_record: enrollment_record}) do
    enrollment_record_json(enrollment_record)
  end

  def enrollment_record_json(%{id: id, academic_year: academic_year, is_current: is_current, start_date: start_date, end_date: end_date, group_id: group_id, group_type: group_type, user_id: user_id, subject_id: subject_id}) do
    %{
      id: id,
      academic_year: academic_year,
      is_current: is_current,
      start_date: start_date,
      end_date: end_date,
      group_id: group_id,
      group_type: group_type,
      user_id: user_id,
      subject_id: subject_id
    }
  end
end
