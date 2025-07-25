defmodule DbserviceWeb.StudentJSON do
  alias DbserviceWeb.UserJSON
  alias Dbservice.Repo

  def index(%{student: student}) do
    for(s <- student, do: render(s))
  end

  def show(%{student: student}) do
    render(student)
  end

  def show_with_user(%{student: student}) do
    for(s <- student, do: render(s))
  end

  def show_student_user_with_compact_fields(%{student: student}) do
    for(s <- student, do: student_user_with_compact_fields(s))
  end

  def render(student) do
    student = Repo.preload(student, :user)

    %{
      id: student.id,
      student_id: student.student_id,
      grade_id: student.grade_id,
      father_name: student.father_name,
      father_phone: student.father_phone,
      father_education_level: student.father_education_level,
      father_profession: student.father_profession,
      mother_name: student.mother_name,
      mother_phone: student.mother_phone,
      mother_education_level: student.mother_education_level,
      mother_profession: student.mother_profession,
      guardian_name: student.guardian_name,
      guardian_relation: student.guardian_relation,
      guardian_phone: student.guardian_phone,
      guardian_education_level: student.guardian_education_level,
      guardian_profession: student.guardian_profession,
      category: student.category,
      has_category_certificate: student.has_category_certificate,
      stream: student.stream,
      physically_handicapped: student.physically_handicapped,
      physically_handicapped_certificate: student.physically_handicapped_certificate,
      annual_family_income: student.annual_family_income,
      monthly_family_income: student.monthly_family_income,
      time_of_device_availability: student.time_of_device_availability,
      has_internet_access: student.has_internet_access,
      primary_smartphone_owner: student.primary_smartphone_owner,
      primary_smartphone_owner_profession: student.primary_smartphone_owner_profession,
      number_of_smartphones: student.number_of_smartphones,
      family_type: student.family_type,
      number_of_four_wheelers: student.number_of_four_wheelers,
      number_of_two_wheelers: student.number_of_two_wheelers,
      has_air_conditioner: student.has_air_conditioner,
      goes_for_tuition_or_other_coaching: student.goes_for_tuition_or_other_coaching,
      know_about_avanti: student.know_about_avanti,
      percentage_in_grade_10_science: student.percentage_in_grade_10_science,
      percentage_in_grade_10_math: student.percentage_in_grade_10_math,
      percentage_in_grade_10_english: student.percentage_in_grade_10_english,
      grade_10_marksheet: student.grade_10_marksheet,
      photo: student.photo,
      user: if(student.user, do: UserJSON.render(student.user), else: nil),
      status: student.status,
      board_stream: student.board_stream,
      planned_competitive_exams: student.planned_competitive_exams,
      school_medium: student.school_medium,
      apaar_id: student.apaar_id
    }
  end

  def student_user_with_compact_fields(student) do
    %{
      id: student.id,
      student_id: student.student_id,
      category: student.category,
      stream: student.stream,
      user: if(student.user, do: UserJSON.user_with_compact_fields(student.user), else: nil),
      apaar_id: student.apaar_id
    }
  end

  def batch_result(%{
        message: message,
        successful: successful,
        failed: failed,
        results: results
      }) do
    %{
      message: message,
      successful: successful,
      failed: failed,
      results:
        Enum.map(results, fn
          {:ok, student} ->
            %{status: :ok, student: render(student)}

          {:error, changeset} ->
            %{status: :error, errors: changeset}
        end)
    }
  end
end
