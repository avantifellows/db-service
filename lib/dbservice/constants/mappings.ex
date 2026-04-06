defmodule Dbservice.Constants.Mappings do
  @moduledoc """
  Centralized constants for data import field mappings, requirements, and metadata.
  """

  @mappings %{
    # User fields
    "user_first_name" => %{
      db_field: "first_name",
      required: ["student", "teacher_addition"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_last_name" => %{
      db_field: "last_name",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_email" => %{
      db_field: "email",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_phone" => %{
      db_field: "phone",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_whatsapp_phone" => %{
      db_field: "whatsapp_phone",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_gender" => %{
      db_field: "gender",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_date_of_birth" => %{
      db_field: "date_of_birth",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :date
    },
    "user_address" => %{
      db_field: "address",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_city" => %{
      db_field: "city",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_district" => %{
      db_field: "district",
      required: ["student", "teacher_addition"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_state" => %{
      db_field: "state",
      required: ["student", "teacher_addition"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "user_pincode" => %{
      db_field: "pincode",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },

    # Student fields
    "student_id" => %{
      db_field: "student_id",
      required: [
        "student",
        "alumni_addition",
        "update_incorrect_batch_id_to_correct_batch_id",
        "update_incorrect_school_to_correct_school",
        "update_incorrect_grade_to_correct_grade",
        "update_incorrect_auth_group_to_correct_auth_group"
      ],
      optional: ["batch_movement", "student_update", "dropout", "re_enrollment"],
      type: :string
    },
    "student_father_name" => %{
      db_field: "father_name",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_father_phone" => %{
      db_field: "father_phone",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_mother_name" => %{
      db_field: "mother_name",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_mother_phone" => %{
      db_field: "mother_phone",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_category" => %{
      db_field: "category",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_stream" => %{
      db_field: "stream",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_family_income" => %{
      db_field: "family_income",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_father_profession" => %{
      db_field: "father_profession",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_father_education_level" => %{
      db_field: "father_education_level",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_mother_profession" => %{
      db_field: "mother_profession",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_mother_education_level" => %{
      db_field: "mother_education_level",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_time_of_device_availability" => %{
      db_field: "time_of_device_availability",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_has_internet_access" => %{
      db_field: "has_internet_access",
      required: ["student"],
      optional: ["student_update"],
      type: :boolean
    },
    "student_primary_smartphone_owner" => %{
      db_field: "primary_smartphone_owner",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_primary_smartphone_owner_profession" => %{
      db_field: "primary_smartphone_owner_profession",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_guardian_name" => %{
      db_field: "guardian_name",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_guardian_relation" => %{
      db_field: "guardian_relation",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_guardian_phone" => %{
      db_field: "guardian_phone",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_guardian_education_level" => %{
      db_field: "guardian_education_level",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_guardian_profession" => %{
      db_field: "guardian_profession",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_annual_family_income" => %{
      db_field: "annual_family_income",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_monthly_family_income" => %{
      db_field: "monthly_family_income",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_number_of_smartphones" => %{
      db_field: "number_of_smartphones",
      required: ["student"],
      optional: ["student_update"],
      type: :integer
    },
    "student_family_type" => %{
      db_field: "family_type",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_number_of_four_wheelers" => %{
      db_field: "number_of_four_wheelers",
      required: ["student"],
      optional: ["student_update"],
      type: :integer
    },
    "student_number_of_two_wheelers" => %{
      db_field: "number_of_two_wheelers",
      required: ["student"],
      optional: ["student_update"],
      type: :integer
    },
    "student_goes_for_tuition_or_other_coaching" => %{
      db_field: "goes_for_tuition_or_other_coaching",
      required: ["student"],
      optional: ["student_update"],
      type: :boolean
    },
    "student_know_about_avanti" => %{
      db_field: "know_about_avanti",
      required: ["student"],
      optional: ["student_update"],
      type: :boolean
    },
    "student_percentage_in_grade_10_science" => %{
      db_field: "percentage_in_grade_10_science",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :float
    },
    "student_percentage_in_grade_10_math" => %{
      db_field: "percentage_in_grade_10_math",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :float
    },
    "student_percentage_in_grade_10_english" => %{
      db_field: "percentage_in_grade_10_english",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :float
    },
    "student_physically_handicapped" => %{
      db_field: "physically_handicapped",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :boolean
    },
    "student_has_category_certificate" => %{
      db_field: "has_category_certificate",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :boolean
    },
    "student_has_air_conditioner" => %{
      db_field: "has_air_conditioner",
      required: ["student"],
      optional: ["student_update"],
      type: :boolean
    },
    "student_board_stream" => %{
      db_field: "board_stream",
      required: ["student"],
      optional: ["student_update", "alumni_addition"],
      type: :string
    },
    "student_school_medium" => %{
      db_field: "school_medium",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_apaar_id" => %{
      db_field: "apaar_id",
      required: [],
      optional: [
        "student",
        "student_update",
        "batch_movement",
        "dropout",
        "alumni_addition",
        "re_enrollment",
        "update_incorrect_batch_id_to_correct_batch_id",
        "update_incorrect_school_to_correct_school",
        "update_incorrect_grade_to_correct_grade",
        "update_incorrect_auth_group_to_correct_auth_group"
      ],
      type: :string
    },

    # System fields
    "addition_date" => %{
      db_field: "addition_date",
      required: ["student"],
      optional: [],
      type: :date
    },
    "auth_group" => %{
      db_field: "auth_group",
      required: ["student", "teacher_addition", "re_enrollment"],
      optional: [],
      type: :string
    },
    "academic_year" => %{
      db_field: "academic_year",
      required: [
        "student",
        "batch_movement",
        "teacher_addition",
        "teacher_batch_assignment",
        "dropout",
        "re_enrollment"
      ],
      optional: [],
      type: :string
    },
    "grade" => %{
      db_field: "grade",
      required: [
        "student",
        "teacher_addition",
        "update_incorrect_grade_to_correct_grade",
        "re_enrollment"
      ],
      optional: [
        "batch_movement",
        "student_update",
        "chapter_addition",
        "resource_addition",
        "topic_addition"
      ],
      type: :string
    },
    "batch_id" => %{
      db_field: "batch_id",
      required: [
        "student",
        "batch_movement",
        "teacher_addition",
        "teacher_batch_assignment",
        "update_incorrect_batch_id_to_correct_batch_id",
        "re_enrollment"
      ],
      optional: [],
      type: :string
    },
    "school_code" => %{
      db_field: "school_code",
      required: ["student", "update_incorrect_school_to_correct_school", "re_enrollment"],
      optional: [],
      type: :string
    },
    "udise_code" => %{
      db_field: "udise_code",
      required: [],
      optional: ["student"],
      type: :string
    },
    "school_name" => %{
      db_field: "school_name",
      required: ["student"],
      optional: [],
      type: :string
    },
    "start_date" => %{
      db_field: "start_date",
      required: [
        "student",
        "batch_movement",
        "teacher_addition",
        "teacher_batch_assignment",
        "dropout",
        "re_enrollment"
      ],
      optional: [],
      type: :date
    },

    # Teacher creation fields
    "subject" => %{
      db_field: "subject",
      required: ["teacher_addition", "chapter_addition", "resource_addition"],
      optional: ["topic_addition"],
      type: :string
    },
    # Chapter addition fields
    "chapterCode" => %{
      db_field: "chapter_code",
      required: ["chapter_addition"],
      optional: ["resource_addition", "topic_addition"],
      type: :string
    },
    "chapterName" => %{
      db_field: "chapter_name",
      required: ["chapter_addition"],
      optional: ["resource_addition", "topic_addition"],
      type: :string
    },
    # Subject addition fields (sheet: Subject; code is optional)
    "Subject" => %{
      db_field: "subject_name",
      required: ["subject_addition"],
      optional: [],
      type: :string
    },
    "code" => %{
      db_field: "code",
      required: ["resource_addition", "product_addition"],
      optional: ["subject_addition", "topic_addition"],
      type: :string
    },
    # Resource addition fields
    "curriculum" => %{
      db_field: "curriculum",
      required: ["resource_addition", "topic_addition"],
      optional: [],
      type: :string
    },
    "topicName" => %{
      db_field: "topic_name",
      required: ["topic_addition"],
      optional: ["resource_addition"],
      type: :string
    },
    "topicCode" => %{
      db_field: "topic_code",
      required: ["topic_addition"],
      optional: ["resource_addition"],
      type: :string
    },
    "resourcePurpose" => %{
      db_field: "resource_purpose",
      required: [],
      optional: ["resource_addition", "topic_addition"],
      type: :string
    },
    "resourceSource" => %{
      db_field: "resource_source",
      required: [],
      optional: ["resource_addition", "topic_addition"],
      type: :string
    },
    "resourceName" => %{
      db_field: "resource_name",
      required: ["resource_addition"],
      optional: ["topic_addition"],
      type: :string
    },
    "resourceType" => %{
      db_field: "resource_type",
      required: ["resource_addition"],
      optional: ["topic_addition"],
      type: :string
    },
    "resourceSubType" => %{
      db_field: "resource_subtype",
      required: [],
      optional: ["resource_addition", "topic_addition"],
      type: :string
    },
    "resourceLink" => %{
      db_field: "resource_link",
      required: ["resource_addition"],
      optional: ["topic_addition"],
      type: :string
    },
    # Auth group addition (sheet headers: Name, Images, User Type, Auth Type, Default Locale, Locale, Locale Data, Tech PM)
    "Name" => %{
      db_field: "name",
      required: ["auth_group_addition", "product_addition", "batch_addition"],
      optional: [],
      type: :string
    },
    "Images" => %{
      db_field: "auth_group_images",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "User Type" => %{
      db_field: "auth_group_user_type",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "Auth Type" => %{
      db_field: "auth_group_auth_type",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "Default Locale" => %{
      db_field: "auth_group_default_locale",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "Locale" => %{
      db_field: "locale",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "Locale Data" => %{
      db_field: "auth_group_locale_data_raw",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    "Tech PM" => %{
      db_field: "auth_group_tech_pm",
      required: [],
      optional: ["auth_group_addition"],
      type: :string
    },
    # Product addition (sheet: Name, Code, Mode, Model, Tech Modules, Type, Led By, Goal)
    "Mode" => %{
      db_field: "mode",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    "Model" => %{
      db_field: "model",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    "Tech Modules" => %{
      db_field: "tech_modules",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    "Type" => %{
      db_field: "type",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    "Led By" => %{
      db_field: "led_by",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    "Goal" => %{
      db_field: "goal",
      required: [],
      optional: ["product_addition"],
      type: :string
    },
    # Program addition (sheet: Program Name, ...) and batch (Program Name = program lookup)
    "Program Name" => %{
      db_field: "name",
      db_field_by_type: %{"batch_addition" => "program_name"},
      required: ["program_addition"],
      optional: ["batch_addition"],
      type: :string
    },
    "Target Outreach" => %{
      db_field: "target_outreach",
      required: [],
      optional: ["program_addition"],
      type: :integer
    },
    "Donor" => %{
      db_field: "donor",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "State/System" => %{
      db_field: "state",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Product Code" => %{
      db_field: "product_code",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "program_model" => %{
      db_field: "model",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "is_current" => %{
      db_field: "is_current",
      required: [],
      optional: ["program_addition"],
      type: :boolean
    },
    "TPM" => %{
      db_field: "program_tpm",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Existing in DB" => %{
      db_field: "program_existing_in_db",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Program in DB?" => %{
      db_field: "program_in_db",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "If yes, product in DB" => %{
      db_field: "program_product_in_db",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Is product in sheet and DB matching?" => %{
      db_field: "program_product_matching",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Remark" => %{
      db_field: "program_remark",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    "Previous Name" => %{
      db_field: "program_previous_name",
      required: [],
      optional: ["program_addition"],
      type: :string
    },
    # Batch addition (sheet: Batch ID, Name, Contact hours per week, Parent Batch ID, Start Date, End Date, Is Parent Batch, Program Name, Auth Group)
    "Batch ID" => %{
      db_field: "batch_id",
      required: [],
      optional: ["batch_addition"],
      type: :string
    },
    "Contact hours per week" => %{
      db_field: "contact_hours_per_week",
      required: [],
      optional: ["batch_addition"],
      type: :integer
    },
    "Parent Batch ID" => %{
      db_field: "parent_batch_id",
      required: [],
      optional: ["batch_addition"],
      type: :string
    },
    "Start Date" => %{
      db_field: "start_date",
      required: [
        "student",
        "batch_movement",
        "teacher_addition",
        "teacher_batch_assignment",
        "dropout",
        "re_enrollment"
      ],
      optional: ["batch_addition"],
      type: :date
    },
    "End Date" => %{
      db_field: "end_date",
      required: [],
      optional: ["batch_addition"],
      type: :date
    },
    "Is Parent Batch" => %{
      db_field: "is_parent_batch",
      required: [],
      optional: ["batch_addition"],
      type: :boolean
    },
    "Auth Group" => %{
      db_field: "auth_group",
      required: [],
      optional: ["batch_addition"],
      type: :string
    },
    "district_code" => %{
      db_field: "district_code",
      required: ["teacher_addition"],
      optional: [],
      type: :string
    },
    "teacher_id" => %{
      db_field: "teacher_id",
      required: ["teacher_addition", "teacher_batch_assignment"],
      optional: [],
      type: :string
    },
    "state_code" => %{
      db_field: "state_code",
      required: ["teacher_addition"],
      optional: [],
      type: :string
    },
    "is_af_teacher" => %{
      db_field: "is_af_teacher",
      required: ["teacher_addition"],
      optional: [],
      type: :boolean
    },

    # Alumni fields (for alumni_addition import)
    "which_competitive_exam_did_you_appear_for" => %{
      db_field: "which_competitive_exam_did_you_appear_for",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "did_you_take_a_gap_year" => %{
      db_field: "did_you_take_a_gap_year",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "why_did_you_take_a_gap_year" => %{
      db_field: "why_did_you_take_a_gap_year",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for" =>
      %{
        db_field:
          "if_avanti_was_not_your_only_source_of_test_prep_coaching_then_what_other_resources_did_you_opt_for",
        required: [],
        optional: ["alumni_addition"],
        type: :string
      },
    "start_year_ug" => %{
      db_field: "start_year_ug",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "college_id_ug" => %{
      db_field: "college_id_ug",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "degree_ug" => %{
      db_field: "degree_ug",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "branch_id_ug" => %{
      db_field: "branch_id_ug",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "year_of_graduation_ug" => %{
      db_field: "year_of_graduation_ug",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "start_year_pg" => %{
      db_field: "start_year_pg",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "college_id_pg" => %{
      db_field: "college_id_pg",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "degree_pg" => %{
      db_field: "degree_pg",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "branch_id_pg" => %{
      db_field: "branch_id_pg",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "year_of_graduation_pg" => %{
      db_field: "year_of_graduation_pg",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "past_internship_orgs" => %{
      db_field: "past_internship_orgs",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "which_year_did_you_start_working" => %{
      db_field: "which_year_did_you_start_working",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "starting_ctc_ug_range" => %{
      db_field: "starting_ctc_ug_range",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_ctc" => %{
      db_field: "current_ctc",
      required: [],
      optional: ["alumni_addition"],
      type: :float
    },
    "current_ctc_range" => %{
      db_field: "current_ctc_range",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_job_city" => %{
      db_field: "current_job_city",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_job_role" => %{
      db_field: "current_job_role",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_job_sector" => %{
      db_field: "current_job_sector",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_org_name" => %{
      db_field: "current_org_name",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "years_of_experience" => %{
      db_field: "years_of_experience",
      required: [],
      optional: ["alumni_addition"],
      type: :integer
    },
    "linkedin_profile_link" => %{
      db_field: "linkedin_profile_link",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job" =>
      %{
        db_field:
          "what_was_your_monthly_household_income_excluding_the_respondent_when_you_were_starting_your_first_job",
        required: [],
        optional: ["alumni_addition"],
        type: :string
      },
    "ug_status" => %{
      db_field: "ug_status",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "pg_status" => %{
      db_field: "pg_status",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "employment_status" => %{
      db_field: "employment_status",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "contact_status" => %{
      db_field: "contact_status",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "current_status" => %{
      db_field: "current_status",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "scholarship_availed" => %{
      db_field: "scholarship_availed",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },
    "skilling_programs" => %{
      db_field: "skilling_programs",
      required: [],
      optional: ["alumni_addition"],
      type: :string
    },

    # Update fields for correction import types
    "old_batch_id" => %{
      db_field: "old_batch_id",
      required: ["update_incorrect_batch_id_to_correct_batch_id"],
      optional: [],
      type: :string
    },
    "auth_group_name" => %{
      db_field: "auth_group_name",
      required: ["update_incorrect_auth_group_to_correct_auth_group"],
      optional: [],
      type: :string
    }
  }

  def get_mappings, do: @mappings

  def get_field_mapping(import_type) do
    @mappings
    |> Enum.filter(fn {_sheet_field, config} ->
      import_type in config.required or import_type in config.optional
    end)
    |> Enum.into(%{}, fn {sheet_field, config} ->
      db_field =
        case config do
          %{db_field_by_type: by_type} when is_map(by_type) ->
            Map.get(by_type, import_type) || config.db_field

          _ ->
            config.db_field
        end

      {sheet_field, db_field}
    end)
  end

  def get_required_headers(import_type) do
    @mappings
    |> Enum.filter(fn {_sheet_field, config} ->
      import_type in config.required
    end)
    |> Enum.map(fn {sheet_field, _config} -> sheet_field end)
  end

  def get_optional_headers(import_type) do
    @mappings
    |> Enum.filter(fn {_sheet_field, config} ->
      import_type in config.optional
    end)
    |> Enum.map(fn {sheet_field, _config} -> sheet_field end)
  end

  def get_all_headers(import_type) do
    get_required_headers(import_type) ++ get_optional_headers(import_type)
  end

  def get_boolean_fields(import_type) do
    @mappings
    |> Enum.filter(fn {_sheet_field, config} ->
      config.type == :boolean and
        (import_type in config.required or import_type in config.optional)
    end)
    |> Enum.map(fn {_sheet_field, config} -> config.db_field end)
  end

  def get_field_type(sheet_field) do
    case Map.get(@mappings, sheet_field) do
      %{type: type} -> type
      _ -> :string
    end
  end

  def get_db_field(sheet_field) do
    case Map.get(@mappings, sheet_field) do
      %{db_field: db_field} -> db_field
      _ -> nil
    end
  end

  def supported_import_types do
    @mappings
    |> Enum.flat_map(fn {_sheet_field, config} ->
      config.required ++ config.optional
    end)
    |> Enum.uniq()
  end
end
