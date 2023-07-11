defmodule Dbservice.Repo.Migrations.ModifyStudentTable do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add(:guardian_name, :string)
      add(:guardian_relation, :string)
      add(:guardian_phone, :string)
      add(:guardian_education_level, :string)
      add(:guardian_profession, :string)
      add(:has_category_certificate, :boolean)
      add(:category_certificate, :string)
      add(:physically_handicapped_certificate, :string)
      add(:annual_family_income, :string)
      add(:monthly_family_income, :string)
      add(:number_of_smartphones, :string)
      add(:family_type, :string)
      add(:number_of_four_wheelers, :string)
      add(:number_of_two_wheelers, :string)
      add(:has_air_conditioner, :boolean)
      add(:goes_for_tuition_or_other_coaching, :string)
      add(:know_about_avanti, :string)
      add(:percentage_in_grade_10_science, :string)
      add(:percentage_in_grade_10_math, :string)
      add(:percentage_in_grade_10_english, :string)
      add(:grade_10_marksheet, :string)
      add(:photo, :string)

      remove(:is_dropper)
      remove(:contact_hours_per_week)
    end
  end
end
