defmodule Dbservice.Constants.Mappings do
  @moduledoc """
  Centralized constants for data import field mappings, requirements, and metadata.
  """

  @mappings %{
    # User fields
    "user_first_name" => %{
      db_field: "first_name",
      required: ["student", "teacher_addition"],
      optional: ["student_update"],
      type: :string
    },
    "user_last_name" => %{
      db_field: "last_name",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_email" => %{
      db_field: "email",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_phone" => %{
      db_field: "phone",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_whatsapp_phone" => %{
      db_field: "whatsapp_phone",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_gender" => %{
      db_field: "gender",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_date_of_birth" => %{
      db_field: "date_of_birth",
      required: ["student"],
      optional: ["student_update"],
      type: :date
    },
    "user_address" => %{
      db_field: "address",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_city" => %{
      db_field: "city",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "user_district" => %{
      db_field: "district",
      required: ["student", "teacher_addition"],
      optional: ["student_update"],
      type: :string
    },
    "user_state" => %{
      db_field: "state",
      required: ["student", "teacher_addition"],
      optional: ["student_update"],
      type: :string
    },
    "user_pincode" => %{
      db_field: "pincode",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },

    # Student fields
    "student_id" => %{
      db_field: "student_id",
      required: ["student", "batch_movement", "student_update"],
      optional: [],
      type: :string
    },
    "student_father_name" => %{
      db_field: "father_name",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_father_phone" => %{
      db_field: "father_phone",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_mother_name" => %{
      db_field: "mother_name",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_mother_phone" => %{
      db_field: "mother_phone",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_category" => %{
      db_field: "category",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_stream" => %{
      db_field: "stream",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_family_income" => %{
      db_field: "family_income",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_father_profession" => %{
      db_field: "father_profession",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_father_education_level" => %{
      db_field: "father_education_level",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_mother_profession" => %{
      db_field: "mother_profession",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_mother_education_level" => %{
      db_field: "mother_education_level",
      required: ["student"],
      optional: ["student_update"],
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
      optional: ["student_update"],
      type: :string
    },
    "student_guardian_relation" => %{
      db_field: "guardian_relation",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_guardian_phone" => %{
      db_field: "guardian_phone",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_guardian_education_level" => %{
      db_field: "guardian_education_level",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_guardian_profession" => %{
      db_field: "guardian_profession",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_annual_family_income" => %{
      db_field: "annual_family_income",
      required: ["student"],
      optional: ["student_update"],
      type: :string
    },
    "student_monthly_family_income" => %{
      db_field: "monthly_family_income",
      required: ["student"],
      optional: ["student_update"],
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
      optional: ["student_update"],
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
      optional: ["student_update"],
      type: :float
    },
    "student_percentage_in_grade_10_math" => %{
      db_field: "percentage_in_grade_10_math",
      required: ["student"],
      optional: ["student_update"],
      type: :float
    },
    "student_percentage_in_grade_10_english" => %{
      db_field: "percentage_in_grade_10_english",
      required: ["student"],
      optional: ["student_update"],
      type: :float
    },
    "student_physically_handicapped" => %{
      db_field: "physically_handicapped",
      required: ["student"],
      optional: ["student_update"],
      type: :boolean
    },
    "student_has_category_certificate" => %{
      db_field: "has_category_certificate",
      required: ["student"],
      optional: ["student_update"],
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
      optional: ["student_update"],
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
      optional: ["student", "student_update"],
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
      required: ["student", "teacher_addition"],
      optional: [],
      type: :string
    },
    "academic_year" => %{
      db_field: "academic_year",
      required: ["student", "batch_movement", "teacher_addition"],
      optional: [],
      type: :string
    },
    "grade" => %{
      db_field: "grade",
      required: ["student", "teacher_addition"],
      optional: ["batch_movement", "student_update"],
      type: :string
    },
    "batch_id" => %{
      db_field: "batch_id",
      required: ["student", "batch_movement", "teacher_addition"],
      optional: [],
      type: :string
    },
    "school_code" => %{
      db_field: "school_code",
      required: ["student"],
      optional: [],
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
      required: ["student", "batch_movement", "teacher_addition"],
      optional: [],
      type: :date
    },

    # Teacher creation fields
    "subject" => %{
      db_field: "subject",
      required: ["teacher_addition"],
      optional: [],
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
      required: ["teacher_addition"],
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

    # Optional fields (can appear in any import)
    "Added by" => %{db_field: "added_by", required: [], optional: ["student"], type: :string},
    "Added on" => %{db_field: "added_on", required: [], optional: ["student"], type: :date}
  }

  def get_mappings, do: @mappings

  def get_field_mapping(import_type) do
    @mappings
    |> Enum.filter(fn {_sheet_field, config} ->
      import_type in config.required or import_type in config.optional
    end)
    |> Enum.into(%{}, fn {sheet_field, config} ->
      {sheet_field, config.db_field}
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
