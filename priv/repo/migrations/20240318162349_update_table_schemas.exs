defmodule Dbservice.Repo.Migrations.UpdateTableSchemas do
  use Ecto.Migration

  def change do
    alter table(:batch) do
      add :start_date, :date
      add :end_date, :date
      add :program_id, references(:programs)

      modify :group_type, :string, null: true
      modify :grouping_id, :integer, null: true
    end

    drop table("batch_program")

    alter table(:enrollment_record) do
      add :start_date, :date
      add :end_date, :date
      add :group_id, references(:groups)
      add :group_type, :string
      add :user_id, references(:users)

      modify :is_current, :boolean, default: true
      modify :date_of_enrollment, :date, null: true
      remove :grade
      remove :student_id
      remove :board_medium
    end

    alter table(:exam) do
      add :cutoff, :map
    end

    alter table(:student_exam_record) do
      add :percentile, :float
      add :all_india_rank, :integer
      add :category_rank, :integer
    end

    alter table(:group_user) do
      remove :program_date_of_joining
      remove :program_student_language
      remove :program_manager
    end

    alter table(:school) do
      add :gender_type, :string
      add :af_school_category, :string
      remove :type
      remove :category
    end

    alter table(:user) do
      remove :middle_name
    end

    alter table(:user_session) do
      add :timestamp, :utc_datetime
      add :type, :string

      remove :start_time
      remove :end_time
    end

    alter table(:user_session) do
      add :popup_form, :boolean
      add :popup_form_id, :integer
      add :signup_form, :integer
      add :signup_form_id, :integer
      
      remove :pop_up_form
      remove :activate_signup
      remove :number_of_fields_in_pop_form
      remove :form_schema_id
    end
  end
end
