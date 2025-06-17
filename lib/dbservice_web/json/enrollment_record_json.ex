defmodule DbserviceWeb.EnrollmentRecordJSON do
  def index(%{enrollment_record: enrollment_record}) do
    for(e <- enrollment_record, do: data(e))
  end

  def show(%{enrollment_record: enrollment_record}) do
    data(enrollment_record)
  end

  defp data(enrollment_record) do
    %{
      id: enrollment_record.id,
      academic_year: enrollment_record.academic_year,
      is_current: enrollment_record.is_current,
      start_date: enrollment_record.start_date,
      end_date: enrollment_record.end_date,
      group_id: enrollment_record.group_id,
      group_type: enrollment_record.group_type,
      user_id: enrollment_record.user_id,
      subject_id: enrollment_record.subject_id
    }
  end
end
