defmodule Dbservice.Users.Student do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Exams.StudentExamRecord

  schema "student" do
    field(:student_id, :string)
    field(:father_name, :string)
    field(:father_phone, :string)
    field(:father_education_level, :string)
    field(:father_profession, :string)
    field(:mother_name, :string)
    field(:mother_phone, :string)
    field(:mother_education_level, :string)
    field(:mother_profession, :string)
    field(:guardian_name, :string)
    field(:guardian_relation, :string)
    field(:guardian_phone, :string)
    field(:guardian_education_level, :string)
    field(:guardian_profession, :string)
    field(:category, :string)
    field(:has_category_certificate, :boolean)
    field(:category_certificate, :string)
    field(:stream, :string)
    field(:physically_handicapped, :boolean)
    field(:physically_handicapped_certificate, :string)
    field(:annual_family_income, :string)
    field(:monthly_family_income, :string)
    field(:time_of_device_availability, :string)
    field(:has_internet_access, :string)
    field(:primary_smartphone_owner, :string)
    field(:primary_smartphone_owner_profession, :string)
    field(:number_of_smartphones, :string)
    field(:family_type, :string)
    field(:number_of_four_wheelers, :string)
    field(:number_of_two_wheelers, :string)
    field(:has_air_conditioner, :boolean)
    field(:goes_for_tuition_or_other_coaching, :string)
    field(:know_about_avanti, :string)
    field(:percentage_in_grade_10_science, :string)
    field(:percentage_in_grade_10_math, :string)
    field(:percentage_in_grade_10_english, :string)
    field(:grade_10_marksheet, :string)
    field(:photo, :string)
    field(:planned_competitive_exams, {:array, :integer})

    belongs_to(:user, User)
    belongs_to(:grade, Grade)

    has_many(:student_exam_record, StudentExamRecord)

    timestamps()
  end

  def changeset(student, attrs) do
    student
    |> cast(attrs, [
      :student_id,
      :user_id,
      :grade_id,
      :father_name,
      :father_phone,
      :father_education_level,
      :father_profession,
      :mother_name,
      :mother_phone,
      :mother_education_level,
      :mother_profession,
      :guardian_name,
      :guardian_relation,
      :guardian_phone,
      :guardian_education_level,
      :guardian_profession,
      :category,
      :has_category_certificate,
      :stream,
      :physically_handicapped,
      :physically_handicapped_certificate,
      :annual_family_income,
      :monthly_family_income,
      :time_of_device_availability,
      :has_internet_access,
      :primary_smartphone_owner,
      :primary_smartphone_owner_profession,
      :number_of_smartphones,
      :family_type,
      :number_of_four_wheelers,
      :number_of_two_wheelers,
      :has_air_conditioner,
      :goes_for_tuition_or_other_coaching,
      :know_about_avanti,
      :percentage_in_grade_10_science,
      :percentage_in_grade_10_math,
      :percentage_in_grade_10_english,
      :grade_10_marksheet,
      :photo,
      :planned_competitive_exams
    ])
    |> validate_required([:user_id])
  end
end
