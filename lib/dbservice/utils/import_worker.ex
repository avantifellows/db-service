defmodule Dbservice.DataImport.ImportWorker do
  @moduledoc """
  This module defines a worker for processing student data imports using Oban.

  It reads CSV files, maps their fields to the database schema, and processes
  student records by creating or updating them in the database. It also
  handles student enrollments based on the imported data.

  The worker updates the import record's status and keeps track of processing
  progress, including errors encountered.
  """
  use Oban.Worker, queue: :imports, max_attempts: 3

  alias Dbservice.DataImport
  alias Dbservice.Users
  alias Dbservice.Grades

  # Field mapping from sheet columns to database fields
  @field_mapping %{
    "student_father_name" => "father_name",
    "student_father_phone" => "father_phone",
    "student_mother_name" => "mother_name",
    "student_mother_phone" => "mother_phone",
    "student_category" => "category",
    "student_stream" => "stream",
    "student_family_income" => "family_income",
    "student_father_profession" => "father_profession",
    "student_father_education_level" => "father_education_level",
    "student_mother_profession" => "mother_profession",
    "student_mother_education_level" => "mother_education_level",
    "student_time_of_device_availability" => "time_of_device_availability",
    "student_has_internet_access" => "has_internet_access",
    "student_primary_smartphone_owner" => "primary_smartphone_owner",
    "student_primary_smartphone_owner_profession" => "primary_smartphone_owner_profession",
    "student_guardian_name" => "guardian_name",
    "student_guardian_relation" => "guardian_relation",
    "student_guardian_phone" => "guardian_phone",
    "student_guardian_education_level" => "guardian_education_level",
    "student_guardian_profession" => "guardian_profession",
    "student_annual_family_income" => "annual_family_income",
    "student_monthly_family_income" => "monthly_family_income",
    "student_number_of_smartphones" => "number_of_smartphones",
    "student_family_type" => "family_type",
    "student_number_of_four_wheelers" => "number_of_four_wheelers",
    "student_number_of_two_wheelers" => "number_of_two_wheelers",
    "student_goes_for_tuition_or_other_coaching" => "goes_for_tuition_or_other_coaching",
    "student_know_about_avanti" => "know_about_avanti",
    "student_percentage_in_grade_10_science" => "percentage_in_grade_10_science",
    "student_percentage_in_grade_10_math" => "percentage_in_grade_10_math",
    "student_percentage_in_grade_10_english" => "percentage_in_grade_10_english",
    # User fields
    "user_first_name" => "first_name",
    "user_last_name" => "last_name",
    "user_email" => "email",
    "user_phone" => "phone",
    "user_whatsapp_phone" => "whatsapp_phone",
    "user_gender" => "gender",
    "user_date_of_birth" => "date_of_birth",
    "user_address" => "address",
    "user_city" => "city",
    "user_district" => "district",
    "user_state" => "state",
    "user_pincode" => "pincode",
    # Boolean fields
    "student_physically_handicapped" => "physically_handicapped",
    "student_has_category_certificate" => "has_category_certificate",
    "student_has_air_conditioner" => "has_air_conditioner",
    # Additional fields that stay the same
    "student_id" => "student_id",
    "academic_year" => "academic_year",
    "start_date" => "start_date",
    "grade" => "grade",
    "school_code" => "school_code",
    "batch_id" => "batch_id",
    "auth_group" => "auth_group"
  }

  @bool_fields [
    "physically_handicapped",
    "has_category_certificate",
    "has_air_conditioner"
  ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => import_id}}) do
    import_record = DataImport.get_import!(import_id)
    total_rows = count_total_rows(import_record.filename, import_record.start_row || 2)

    # Update status to processing
    DataImport.update_import(import_record, %{status: "processing", total_rows: total_rows})

    # Broadcast status update
    Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})

    # Process the file based on type
    case import_record.type do
      "student" -> process_student_import(import_record)
      _ -> {:error, "Unsupported import type"}
    end
  end

  # New function to map sheet column names to database field names
  defp map_fields(record) do
    record
    |> map_string_fields()
    |> map_boolean_fields()
    |> add_grade_id()
  end

  defp map_string_fields(record) do
    Enum.reduce(@field_mapping, %{}, fn {sheet_column, db_field}, acc ->
      case Map.get(record, sheet_column) do
        nil -> acc
        value -> Map.put(acc, db_field, value)
      end
    end)
  end

  defp map_boolean_fields(record) do
    Enum.reduce(@bool_fields, record, fn field, acc ->
      case Map.get(acc, field) do
        "TRUE" -> Map.put(acc, field, true)
        "FALSE" -> Map.put(acc, field, false)
        _ -> acc
      end
    end)
  end

  defp add_grade_id(record) do
    case Map.get(record, "grade") do
      nil ->
        record

      grade ->
        case Grades.get_grade_by_number(grade) do
          %Dbservice.Grades.Grade{} = grade_record ->
            Map.put(record, "grade_id", grade_record.id)

          {:ok, grade_record} ->
            Map.put(record, "grade_id", grade_record.id)

          _ ->
            record
        end
    end
  end

  defp count_total_rows(filename, start_row) do
    path = Path.join(["priv", "static", "uploads", filename])

    try do
      count =
        path
        |> File.stream!()
        |> Stream.drop(start_row - 1)
        |> CSV.decode!(
          # Comma separator
          separator: ?,,
          # Explicit escape character
          escape_character: ?",
          # Use headers to be more lenient
          headers: true,
          # Allow variable row lengths
          validate_row_length: false,
          # Allow multi-line escapes
          escape_max_lines: 2
        )
        |> Enum.count()

      max(0, count)
    rescue
      _e in CSV.StrayEscapeCharacterError ->
        # Try alternative parsing if standard CSV parsing fails
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.drop(start_row - 1)
        |> Enum.filter(fn line -> String.trim(line) != "" end)
        |> length()

      _ ->
        # Fallback to simple line counting
        path
        |> File.read!()
        |> String.split("\n")
        |> Enum.drop(start_row - 1)
        |> Enum.filter(fn line -> String.trim(line) != "" end)
        |> length()
    end
  end

  defp process_student_import(import_record) do
    path = Path.join(["priv", "static", "uploads", import_record.filename])
    start_row = import_record.start_row || 2

    with {:ok, parsed_records} <- parse_csv_records(path, start_row),
         {:ok, processed_records} <- process_parsed_records(parsed_records, import_record) do
      finalize_import(import_record, processed_records)
    else
      {:error, reason} -> handle_import_error(import_record, reason)
    end
  end

  defp parse_csv_records(path, start_row) do
    try do
      records =
        path
        |> File.stream!()
        |> CSV.decode!(
          separator: ?,,
          escape_character: ?",
          headers: true,
          validate_row_length: false,
          escape_max_lines: 2
        )
        |> Stream.with_index(1)
        |> Stream.filter(fn {_record, index} -> index >= start_row - 1 end)
        |> Stream.map(fn {record, index} -> {extract_fields(record), index} end)
        |> Stream.map(fn {record, index} -> {map_fields(record), index} end)
        |> Enum.to_list()

      {:ok, records}
    rescue
      _e in CSV.StrayEscapeCharacterError ->
        {:error, "CSV parsing failed: Stray escape character. Check file formatting."}

      error ->
        {:error, "Unexpected error parsing CSV: #{inspect(error)}"}
    end
  end

  defp process_parsed_records(records, import_record) do
    Enum.reduce_while(records, {:ok, []}, fn {record, index}, {:ok, processed_records} ->
      case process_single_record(record, index, import_record) do
        {:ok, result} ->
          {:cont, {:ok, [result | processed_records]}}

        {:error, reason} ->
          # Halt the entire import process if any row fails
          {:halt, {:error, "Error processing row #{index}: #{reason}"}}
      end
    end)
    |> case do
      {:ok, processed_records} -> {:ok, Enum.reverse(processed_records)}
      error -> error
    end
  end

  defp process_single_record(record, index, import_record) do
    try do
      case process_student_record(record) do
        {:ok, _} = result ->
          update_import_progress(import_record, index, :success)
          result

        {:error, reason} = error ->
          update_import_progress(import_record, index, :error, reason)
          error
      end
    rescue
      e ->
        update_import_progress(import_record, index, :exception, e)
        {:error, Exception.message(e)}
    end
  end

  defp update_import_progress(import_record, index, status, error \\ nil) do
    processed_rows = index + 1 - (import_record.start_row || 2)

    update_params = %{
      processed_rows: processed_rows
    }

    update_params =
      case status do
        :error ->
          Map.merge(update_params, %{
            error_count: (import_record.error_count || 0) + 1,
            error_details: [
              %{row: index + 1, error: inspect(error)}
              | import_record.error_details || []
            ]
          })

        :exception ->
          Map.merge(update_params, %{
            error_count: (import_record.error_count || 0) + 1,
            error_details: [
              %{row: index + 1, error: Exception.message(error)}
              | import_record.error_details || []
            ]
          })

        _ ->
          update_params
      end

    DataImport.update_import(import_record, update_params)

    # Broadcast progress update
    Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})
  end

  defp finalize_import(import_record, records) do
    total_records = length(records)

    DataImport.complete_import(
      import_record.id,
      total_records
    )

    {:ok, records}
  end

  defp handle_import_error(import_record, reason) do
    DataImport.fail_import(
      import_record.id,
      reason
    )

    {:error, reason}
  end

  defp extract_fields(record) do
    case record do
      # If the record is already a map with multiple keys, return it directly
      record when is_map(record) and map_size(record) > 1 ->
        record

      # Handle single-key map scenario (potentially problematic CSV parsing)
      record when is_map(record) ->
        combined_key = Map.keys(record) |> List.first()
        combined_value = Map.values(record) |> List.first()

        # More robust splitting with CSV parsing
        headers = String.split(combined_key, ",", trim: true)
        values = String.split(combined_value, ",", trim: true)

        # Ensure headers and values have the same length
        headers
        |> Enum.zip(values)
        |> Enum.into(%{}, fn
          {header, value} when is_binary(header) ->
            # Trim whitespace and remove quotes if present
            {String.trim(header), String.trim(value, "\"' ")}

          _ ->
            nil
        end)
        |> Enum.reject(fn {_, v} -> v == nil end)
        |> Enum.into(%{})
    end
  end

  defp process_student_record(record) do
    case Users.get_student_by_student_id(record["student_id"]) do
      nil ->
        with {:ok, student} <- Users.create_student_with_user(record),
             student <- Dbservice.Repo.preload(student, [:user]),
             {:ok, _} <- DataImport.StudentEnrollment.create_enrollments(student.user, record) do
          {:ok, student}
        else
          {:error, _} = error -> error
        end

      existing_student ->
        user = Users.get_user!(existing_student.user_id)

        with {:ok, updated_student} <-
               Users.update_student_with_user(existing_student, user, record),
             {:ok, _} <- DataImport.StudentEnrollment.create_enrollments(user, record) do
          {:ok, updated_student}
        else
          {:error, _} = error -> error
        end
    end
  end
end
