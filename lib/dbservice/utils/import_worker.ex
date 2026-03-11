defmodule Dbservice.DataImport.ImportWorker do
  @moduledoc """
  Defines a worker for processing data imports using Oban.

  This worker reads CSV files, maps their fields to the database schema, and processes
  records by creating or updating them in the database. It also handles enrollments
  and other related operations based on the imported data.

  The worker updates the import record's status and keeps track of processing
  progress, including errors encountered.
  """
  use Oban.Worker, queue: :imports, max_attempts: 3

  alias Dbservice.DataImport
  alias Dbservice.Constants.Mappings
  alias Dbservice.Users
  alias Dbservice.Grades
  alias Dbservice.Services.StudentUpdateService
  alias Dbservice.Services.DropoutService
  alias Dbservice.Services.ReEnrollmentService
  alias Dbservice.Utils.ChangesetFormatter
  alias Dbservice.Colleges
  alias Dbservice.Branches
  alias Dbservice.Chapters
  alias Dbservice.Subjects
  alias Dbservice.Curriculums
  alias Dbservice.Topics
  alias Dbservice.Purposes
  alias Dbservice.Resources
  alias Dbservice.ResourceCurriculums
  alias Dbservice.ResourceChapters
  alias Dbservice.ResourceTopics

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => import_id}}) do
    import_record = DataImport.get_import!(import_id)

    with {:ok, updated_import} <- initialize_import_processing(import_record),
         {:ok, processor_fn} <- get_record_processor(updated_import.type) do
      case process_import(updated_import, processor_fn) do
        {:ok, _processed_records} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Initialize import processing with total rows calculation and status update
  defp initialize_import_processing(import_record) do
    # count_total_rows now returns the exact count of rows to be processed
    total_rows = count_total_rows(import_record.filename, import_record.start_row || 2)

    case DataImport.update_import(import_record, %{status: "processing", total_rows: total_rows}) do
      {:ok, updated_import} ->
        # Broadcast status update so UI shows total rows immediately
        Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})
        {:ok, updated_import}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Get the appropriate record processor function for the import type
  defp get_record_processor(import_type) do
    processor_map = %{
      "teacher_addition" => &process_teacher_record/1,
      "chapter_addition" => &process_chapter_record/1,
      "subject_addition" => &process_subject_record/1,
      "resource_addition" => &process_resource_record/1,
      "student" => &process_student_record/1,
      "student_update" => &process_student_update_record/1,
      "batch_movement" => &process_batch_movement_record/1,
      "alumni_addition" => &process_alumni_record/1,
      "teacher_batch_assignment" => &process_teacher_batch_assignment_record/1,
      "update_incorrect_batch_id_to_correct_batch_id" => &process_batch_id_update_record/1,
      "update_incorrect_school_to_correct_school" => &process_school_update_record/1,
      "update_incorrect_grade_to_correct_grade" => &process_grade_update_record/1,
      "update_incorrect_auth_group_to_correct_auth_group" => &process_auth_group_update_record/1,
      "dropout" => &process_dropout_record/1,
      "re_enrollment" => &process_re_enrollment_record/1
    }

    case Map.get(processor_map, import_type) do
      nil -> {:error, "Unsupported import type"}
      processor_fn -> {:ok, processor_fn}
    end
  end

  # Generic import processing function
  defp process_import(import_record, record_processor_fn) do
    path = Path.join(["priv", "static", "uploads", import_record.filename])
    start_row = import_record.start_row || 2

    case parse_csv_records(path, start_row, import_record.type) do
      {:ok, parsed_records} ->
        try do
          case process_parsed_records(
                 parsed_records,
                 import_record,
                 record_processor_fn
               ) do
            {:ok, processed_records} -> finalize_import(import_record, processed_records)
            {:error, reason} -> handle_import_error(import_record, reason)
          end
        rescue
          e -> handle_import_error(import_record, Exception.message(e))
        end

      {:error, {error_message, row_info}} ->
        # Structured error with explicit row number
        update_params = %{
          error_count: 1,
          error_details: [%{row: row_info, error: error_message}]
        }

        DataImport.update_import(import_record, update_params)
        Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})
        handle_import_error(import_record, error_message)
    end
  end

  # Generic CSV parsing function
  defp parse_csv_records(path, start_row, import_type) do
    field_extractor_fn = get_field_extractor_fn(import_type)
    parse_csv_records_with_extractor(path, start_row, field_extractor_fn)
  end

  # Unified field extractor function for all import types
  defp get_field_extractor_fn(import_type) do
    fn {record, row_number} ->
      record
      |> extract_field_mappings(import_type)
      |> map_boolean_fields(import_type)
      |> add_grade_id(row_number)
      |> add_subject_id(row_number)
      |> add_curriculum_id(row_number)
      |> add_chapter_id(row_number)
      |> add_topic_id(row_number)
      |> add_purpose_ids_for_resource(row_number)
      |> add_college_ids(row_number)
      |> add_branch_ids(row_number)
    end
  end

  # Unified field extraction using mappings
  defp extract_field_mappings(record, import_type) do
    field_mapping = Mappings.get_field_mapping(import_type)

    field_mapping
    |> Enum.reduce(%{}, fn {sheet_col, db_field}, acc ->
      case Map.get(record, sheet_col) do
        nil -> acc
        # Skip empty values instead of defaulting to ""
        "" -> acc
        value -> Map.put(acc, db_field, value)
      end
    end)
  end

  defp map_boolean_fields(record, import_type) do
    bool_fields = Mappings.get_boolean_fields(import_type)

    Enum.reduce(bool_fields, record, fn field, acc ->
      case Map.get(acc, field) do
        "TRUE" -> Map.put(acc, field, true)
        "FALSE" -> Map.put(acc, field, false)
        "Yes" -> Map.put(acc, field, true)
        "No" -> Map.put(acc, field, false)
        _ -> acc
      end
    end)
  end

  defp add_grade_id(record, row_number) do
    case Map.get(record, "grade") do
      nil ->
        record

      grade when grade == "" ->
        record

      grade ->
        try do
          grade_number = parse_grade_number(grade)

          case grade_number do
            nil ->
              record

            num ->
              case Grades.get_grade_by_number(num) do
                %Dbservice.Grades.Grade{} = grade_record ->
                  Map.put(record, "grade_id", grade_record.id)

                {:ok, grade_record} ->
                  Map.put(record, "grade_id", grade_record.id)

                _ ->
                  record
              end
          end
        rescue
          error ->
            # Preserve original stacktrace while adding context
            reraise "Failed to lookup grade '#{grade}' on row #{row_number}: #{Exception.message(error)}",
                    __STACKTRACE__
        end
    end
  end

  # Parse grade from string "9", "10" etc. to integer for DB lookup (grade.number is integer)
  defp parse_grade_number(grade) when is_integer(grade), do: grade

  defp parse_grade_number(grade) when is_binary(grade) do
    grade = String.trim(grade)

    case Integer.parse(grade) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_grade_number(_), do: nil

  defp add_subject_id(record, row_number) do
    case Map.get(record, "subject") do
      nil ->
        record

      subject_name when is_binary(subject_name) ->
        try do
          subject_name = String.trim(subject_name)

          case DataImport.TeacherEnrollment.get_subject_id_by_name(subject_name) do
            nil -> record
            subject_id -> Map.put(record, "subject_id", subject_id)
          end
        rescue
          error ->
            # Preserve original stacktrace while adding context
            reraise "Failed to lookup subject '#{subject_name}' on row #{row_number}: #{Exception.message(error)}",
                    __STACKTRACE__
        end
    end
  end

  defp add_curriculum_id(record, row_number) do
    case Map.get(record, "curriculum") do
      nil ->
        record

      name when is_binary(name) ->
        name = String.trim(name)
        if name == "", do: record, else: do_add_curriculum_id(record, name, row_number)

      _ ->
        record
    end
  end

  defp do_add_curriculum_id(record, name, row_number) do
    case Curriculums.get_curriculum_by_name(name) do
      nil -> record
      curriculum -> Map.put(record, "curriculum_id", curriculum.id)
    end
  rescue
    error ->
      reraise "Failed to lookup curriculum '#{name}' on row #{row_number}: #{Exception.message(error)}",
              __STACKTRACE__
  end

  defp add_chapter_id(record, row_number) do
    case Map.get(record, "chapter_code") do
      nil ->
        record

      "" ->
        record

      code when is_binary(code) ->
        code = String.trim(code)

        case Chapters.get_chapter_by_code(code) do
          nil -> record
          chapter -> Map.put(record, "chapter_id", chapter.id)
        end

      _ ->
        record
    end
  rescue
    error ->
      reraise "Failed to lookup chapter by code on row #{row_number}: #{Exception.message(error)}",
              __STACKTRACE__
  end

  defp add_topic_id(record, row_number) do
    case Map.get(record, "topic_code") do
      nil ->
        record

      "" ->
        record

      code when is_binary(code) ->
        code = String.trim(code)

        case Topics.get_topic_by_code(code) do
          nil -> record
          topic -> Map.put(record, "topic_id", topic.id)
        end

      _ ->
        record
    end
  rescue
    error ->
      reraise "Failed to lookup topic by code on row #{row_number}: #{Exception.message(error)}",
              __STACKTRACE__
  end

  defp add_purpose_ids_for_resource(record, _row_number) do
    case Map.get(record, "resource_purpose") do
      nil ->
        record

      "" ->
        record

      purpose_str when is_binary(purpose_str) ->
        purpose_names =
          purpose_str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

        ids =
          Enum.flat_map(purpose_names, fn name ->
            case Purposes.get_purpose_by_name(name) do
              nil -> []
              purpose -> [purpose.id]
            end
          end)

        if ids == [], do: record, else: Map.put(record, "purpose_ids", ids)

      _ ->
        record
    end
  end

  defp add_college_ids(record, row_number) do
    record
    |> maybe_put_college_pk("college_id_ug", row_number)
    |> maybe_put_college_pk("college_id_pg", row_number)
  end

  defp maybe_put_college_pk(record, field, row_number) do
    case Map.get(record, field) do
      nil ->
        record

      college_code when is_binary(college_code) ->
        try do
          case Colleges.get_college_by_college_id(college_code) do
            nil -> record
            %{id: college_pk} -> Map.put(record, field, college_pk)
          end
        rescue
          error ->
            reraise "Failed to lookup #{field} '#{college_code}' on row #{row_number}: #{Exception.message(error)}",
                    __STACKTRACE__
        end

      _ ->
        record
    end
  end

  defp add_branch_ids(record, row_number) do
    record
    |> maybe_put_branch_pk("branch_id_ug", row_number)
    |> maybe_put_branch_pk("branch_id_pg", row_number)
  end

  defp maybe_put_branch_pk(record, field, row_number) do
    case Map.get(record, field) do
      nil ->
        record

      branch_code when is_binary(branch_code) ->
        try do
          case Branches.get_branch_by_branch_id(branch_code) do
            nil -> record
            %{id: branch_pk} -> Map.put(record, field, branch_pk)
          end
        rescue
          error ->
            reraise "Failed to lookup #{field} '#{branch_code}' on row #{row_number}: #{Exception.message(error)}",
                    __STACKTRACE__
        end

      _ ->
        record
    end
  end

  # Generic CSV parsing function that accepts a field extraction function
  defp parse_csv_records_with_extractor(path, start_row, field_extractor_fn) do
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
        # First index: tracks position in decoded CSV (1 = first data row after header)
        |> Stream.with_index(1)
        # Filter to only process rows from start_row onward
        |> Stream.filter(fn {_record, index} -> index >= start_row - 1 end)
        # Second index: tracks sequential processing count (1, 2, 3...)
        |> Stream.with_index(1)
        |> Stream.map(fn {{record, csv_index}, processing_index} ->
          # csv_index is the original row index in the decoded CSV (1-based)
          # processing_index is the sequential processing count (1, 2, 3...)
          # Compute actual CSV row number (header is row 1, so add 1)
          csv_row_number = csv_index + 1

          try do
            # Use processing_index for progress tracking, csv_row_number for errors
            {field_extractor_fn.({record, csv_row_number}), processing_index}
          rescue
            e ->
              {:error, Exception.message(e), csv_row_number}
          end
        end)
        |> Enum.to_list()

      # If any field extraction failed, return first structured error with row number
      case Enum.find(records, fn
             {:error, _msg, _row} -> true
             _ -> false
           end) do
        {:error, msg, row} -> {:error, {msg, row}}
        nil -> {:ok, records}
      end
    rescue
      _e in CSV.StrayEscapeCharacterError ->
        {:error,
         {"CSV parsing failed: Stray escape character. Check file formatting.", "CSV Parsing"}}

      error ->
        {:error, {"Unexpected error during CSV processing: #{inspect(error)}", "CSV Parsing"}}
    end
  end

  # Generic record processing with configurable error handling
  defp process_parsed_records(records, import_record, record_processor_fn) do
    initial_acc = {:ok, []}

    result =
      Enum.reduce_while(records, initial_acc, fn {record, index}, {:ok, processed_records} ->
        # Check if import has been halted before processing each record
        current_import = DataImport.get_import!(import_record.id)

        if current_import.status == "stopped" do
          {:halt, {:ok, Enum.reverse(processed_records)}}
        else
          handle_record_processing(
            record,
            index,
            import_record,
            record_processor_fn,
            processed_records
          )
        end
      end)

    case result do
      {:ok, processed_records} -> {:ok, Enum.reverse(processed_records)}
      error -> error
    end
  end

  # Helper function to handle individual record processing within the reduce_while loop
  defp handle_record_processing(
         record,
         index,
         import_record,
         record_processor_fn,
         processed_records
       ) do
    case process_single_record(record, index, import_record, record_processor_fn) do
      {:ok, result} ->
        {:cont, {:ok, [result | processed_records]}}

      {:error, reason} ->
        handle_record_error(index, reason, import_record, processed_records)
    end
  end

  # Helper function to handle errors during record processing
  defp handle_record_error(index, reason, import_record, _processed_records) do
    # index is now the processing index (1, 2, 3...)
    # Calculate actual CSV row number: start_row + (processing_index - 1)
    start_row = import_record.start_row || 2
    csv_row_number = start_row + index - 1

    # Update import record with error details before halting
    update_params = %{
      error_count: (import_record.error_count || 0) + 1,
      error_details: [
        %{row: csv_row_number, error: reason}
        | import_record.error_details || []
      ]
    }

    DataImport.update_import(import_record, update_params)

    # Don't broadcast here as the error will be handled by handle_import_error which calls fail_import

    # Halt the entire import process if any row fails
    {:halt, {:error, "Error processing row #{csv_row_number}: #{reason}"}}
  end

  # Generic single record processing
  defp process_single_record(record, index, import_record, record_processor_fn) do
    try do
      case record_processor_fn.(record) do
        {:ok, _} = result ->
          update_import_progress(import_record, index)
          result

        {:error, reason} = error ->
          # Don't update progress for errors - only log the error
          log_import_error(import_record, index, reason)
          error
      end
    rescue
      e ->
        # Don't update progress for exceptions - only log the error
        log_import_error(import_record, index, Exception.message(e))
        {:error, Exception.message(e)}
    end
  end

  # Log import error without updating processed rows count
  defp log_import_error(import_record, index, error) do
    # index is now the processing index (1, 2, 3...)
    # Calculate actual CSV row number
    start_row = import_record.start_row || 2
    csv_row_number = start_row + index - 1

    error_message = format_error_message(error, csv_row_number)

    update_params = %{
      error_count: (import_record.error_count || 0) + 1,
      error_details: [
        %{row: csv_row_number, error: error_message}
        | import_record.error_details || []
      ]
    }

    DataImport.update_import(import_record, update_params)

    # Broadcast error update
    Phoenix.PubSub.broadcast(
      Dbservice.PubSub,
      "imports",
      {:import_updated, import_record.id}
    )
  end

  # Record processor functions for each import type
  defp process_student_record(record) do
    # For student imports, if student already exists, returns error
    # Check if student exists first to determine if this would be an update
    existing_student = Users.get_student_by_id_or_apaar_id(record)

    case Users.create_or_update_student(record) do
      {:ok, student} ->
        handle_student_creation_result(existing_student, student, record)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_student_creation_result(nil, student, record) do
    # Student was created - proceed with enrollments
    student = Dbservice.Repo.preload(student, [:user])

    case DataImport.StudentEnrollment.create_enrollments(student.user, record) do
      {:ok, _} -> {:ok, {:ok, student}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_student_creation_result(_existing_student, student, _record) do
    # Student already exists - return detailed error (student_update import type should be used for updates)
    {:error, build_student_exists_error_message(student)}
  end

  defp build_student_exists_error_message(student) do
    auth_group_name = get_auth_group_name_for_student(student)

    identifiers = build_identifier_string(student)

    if identifiers != "" do
      "Student already exists with #{identifiers} and auth_group: #{auth_group_name}. Use 'Update Student Details' import type for updates."
    else
      "Student already exists with auth_group: #{auth_group_name}. Use 'Update Student Details' import type for updates."
    end
  end

  defp get_auth_group_name_for_student(student) do
    user = Users.get_user!(student.user_id)

    auth_groups =
      Dbservice.GroupUsers.get_group_user_by_user_id_and_type(user.id, "auth_group")

    case auth_groups do
      [%{group: %{child_id: child_id}} | _] ->
        case Dbservice.AuthGroups.get_auth_group!(child_id) do
          %{name: name} -> name
          _ -> "unknown"
        end

      _ ->
        "unknown"
    end
  end

  defp build_identifier_string(student) do
    student_id_info =
      if nil_or_empty?(student.student_id) do
        nil
      else
        "Student ID: #{student.student_id}"
      end

    apaar_id_info =
      if nil_or_empty?(student.apaar_id) do
        nil
      else
        "APAAR ID: #{student.apaar_id}"
      end

    [student_id_info, apaar_id_info] |> Enum.filter(&(&1 != nil)) |> Enum.join(", ")
  end

  defp nil_or_empty?(value), do: is_nil(value) or value == ""

  defp process_student_update_record(record) do
    # Accept either student_id or apaar_id (like addition and batch movement)
    student_id = record["student_id"]
    apaar_id = record["apaar_id"]

    if (is_nil(student_id) or student_id == "") and (is_nil(apaar_id) or apaar_id == "") do
      {:error, "Either student_id or apaar_id is required for student updates"}
    else
      case Users.get_student_by_id_or_apaar_id(record) do
        nil ->
          {:error,
           "Student not found. student_id: #{record["student_id"]}, apaar_id: #{record["apaar_id"]}"}

        student ->
          StudentUpdateService.update_student_with_user_data(student, record)
      end
    end
  end

  defp process_batch_movement_record(record) do
    DataImport.BatchMovement.process_batch_movement(record)
  end

  defp process_dropout_record(record) do
    # Accept either student_id or apaar_id (like batch movement)
    student_id = record["student_id"]
    apaar_id = record["apaar_id"]

    if (is_nil(student_id) or student_id == "") and (is_nil(apaar_id) or apaar_id == "") do
      {:error, "Either student_id or apaar_id is required for dropout"}
    else
      process_dropout_for_student(record)
    end
  end

  defp process_dropout_for_student(record) do
    case Users.get_student_by_id_or_apaar_id(record) do
      nil ->
        {:error,
         "Student not found. student_id: #{record["student_id"]}, apaar_id: #{record["apaar_id"]}"}

      student ->
        start_date = record["start_date"]
        academic_year = record["academic_year"]
        DropoutService.process_dropout(student, start_date, academic_year)
    end
  end

  defp process_re_enrollment_record(record) do
    # Accept either student_id or apaar_id
    student_id = record["student_id"]
    apaar_id = record["apaar_id"]

    if (is_nil(student_id) or student_id == "") and (is_nil(apaar_id) or apaar_id == "") do
      {:error, "Either student_id or apaar_id is required for re-enrollment"}
    else
      process_re_enrollment_for_student(record)
    end
  end

  defp process_re_enrollment_for_student(record) do
    case Users.get_student_by_id_or_apaar_id(record) do
      nil ->
        {:error,
         "Student not found. student_id: #{record["student_id"]}, apaar_id: #{record["apaar_id"]}"}

      student ->
        ReEnrollmentService.process_re_enrollment(student, record)
    end
  end

  defp process_teacher_record(record) do
    case Users.get_teacher_by_teacher_id(record["teacher_id"]) do
      nil ->
        with {:ok, teacher} <- Users.create_teacher_with_user(record),
             teacher <- Dbservice.Repo.preload(teacher, [:user]),
             {:ok, _} <- DataImport.TeacherEnrollment.create_enrollments(teacher.user, record) do
          {:ok, teacher}
        else
          {:error, _} = error -> error
        end

      existing_teacher ->
        user = Users.get_user!(existing_teacher.user_id)

        with {:ok, updated_teacher} <-
               Users.update_teacher_with_user(existing_teacher, user, record),
             {:ok, _} <- DataImport.TeacherEnrollment.create_enrollments(user, record) do
          {:ok, updated_teacher}
        else
          {:error, _} = error -> error
        end
    end
  end

  defp process_chapter_record(record) do
    chapter_code = record["chapter_code"]
    grade_id = record["grade_id"]
    subject_id = record["subject_id"]
    chapter_name = record["chapter_name"]

    if is_nil(subject_id) do
      {:error,
       "Could not resolve subject for row (code: #{chapter_code}). Ensure the subject value exists in the database (e.g. 'General Knowledge & Current Affairs')."}
    else
      name_array = build_chapter_name_array(chapter_name)

      attrs = %{
        "code" => chapter_code,
        "subject_id" => subject_id,
        "name" => name_array
      }

      attrs =
        if is_nil(grade_id) do
          attrs
        else
          Map.put(attrs, "grade_id", grade_id)
        end

      case Chapters.get_chapter_by_code(chapter_code) do
        nil ->
          Chapters.create_chapter(attrs)

        existing_chapter ->
          Chapters.update_chapter(existing_chapter, attrs)
      end
    end
  end

  defp build_chapter_name_array(nil), do: [%{"lang_code" => "en", "chapter" => ""}]
  defp build_chapter_name_array(""), do: [%{"lang_code" => "en", "chapter" => ""}]

  defp build_chapter_name_array(chapter_name) when is_binary(chapter_name) do
    [%{"lang_code" => "en", "chapter" => chapter_name}]
  end

  defp process_subject_record(record) do
    subject_name = record["subject_name"]
    code = Map.get(record, "code")

    if is_nil(subject_name) or subject_name == "" do
      {:error, "Subject name is required"}
    else
      name_array = build_subject_name_array(subject_name)
      attrs = %{"name" => name_array}
      attrs = if code != nil and code != "", do: Map.put(attrs, "code", code), else: attrs

      case Subjects.get_subject_by_name(subject_name) do
        nil ->
          Subjects.create_subject(attrs)

        existing_subject ->
          Subjects.update_subject(existing_subject, attrs)
      end
    end
  end

  defp build_subject_name_array(nil), do: [%{"lang_code" => "en", "subject" => ""}]
  defp build_subject_name_array(""), do: [%{"lang_code" => "en", "subject" => ""}]

  defp build_subject_name_array(subject_name) when is_binary(subject_name) do
    [%{"lang_code" => "en", "subject" => subject_name}]
  end

  defp process_resource_record(record) do
    code = record["code"]
    curriculum_id = record["curriculum_id"]
    grade_id = record["grade_id"]
    subject_id = record["subject_id"]
    chapter_id = record["chapter_id"]
    topic_id = record["topic_id"]
    resource_name = record["resource_name"]
    resource_type = record["resource_type"]
    resource_link = record["resource_link"]

    cond do
      is_nil(resource_type) or resource_type == "" ->
        {:error, "resourceType is required for row (code: #{code})"}

      is_nil(resource_link) or resource_link == "" ->
        {:error, "resourceLink is required for row (code: #{code})"}

      is_nil(resource_name) or resource_name == "" ->
        {:error, "resourceName is required for row (code: #{code})"}

      is_nil(curriculum_id) ->
        {:error,
         "Could not resolve curriculum for row (code: #{code}). Ensure curriculum value exists."}

      true ->
        name_array = build_resource_name_array(resource_name)
        type_params = %{"src_link" => String.trim(resource_link)}

        resource_attrs =
          %{
            "code" => code,
            "name" => name_array,
            "type" => String.trim(resource_type),
            "type_params" => type_params
          }
          |> maybe_put("subtype", record["resource_subtype"])
          |> maybe_put("source", record["resource_source"])
          |> maybe_put("purpose_ids", record["purpose_ids"])

        with {:ok, resource} <- create_or_update_resource(resource_attrs, code),
             :ok <-
               maybe_ensure_resource_curriculum(resource.id, curriculum_id, grade_id, subject_id),
             :ok <- ensure_resource_chapter(resource.id, chapter_id),
             :ok <- ensure_resource_topic(resource.id, topic_id) do
          {:ok, resource}
        end
    end
  end

  defp build_resource_name_array(nil), do: [%{"lang_code" => "en", "resource" => ""}]
  defp build_resource_name_array(""), do: [%{"lang_code" => "en", "resource" => ""}]

  defp build_resource_name_array(name) when is_binary(name) do
    [%{"lang_code" => "en", "resource" => name}]
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp create_or_update_resource(attrs, code) do
    case Resources.get_resource_by_code(code) do
      nil -> Resources.create_resource(attrs)
      existing -> Resources.update_resource(existing, attrs)
    end
  end

  # Only create/update resource_curriculum when grade_id is present (grade is nullable for resource addition)
  defp maybe_ensure_resource_curriculum(_resource_id, _curriculum_id, grade_id, _subject_id)
       when is_nil(grade_id) or grade_id == "",
       do: :ok

  defp maybe_ensure_resource_curriculum(resource_id, curriculum_id, grade_id, subject_id) do
    ensure_resource_curriculum(resource_id, curriculum_id, grade_id, subject_id)
  end

  defp ensure_resource_curriculum(resource_id, curriculum_id, grade_id, subject_id) do
    attrs = %{
      "resource_id" => resource_id,
      "curriculum_id" => curriculum_id,
      "grade_id" => grade_id,
      "subject_id" => subject_id
    }

    case ResourceCurriculums.get_resource_curriculum_by_resource_id_and_curriculum_id(
           resource_id,
           curriculum_id
         ) do
      nil ->
        ResourceCurriculums.create_resource_curriculum(attrs) |> to_ok()

      existing ->
        ResourceCurriculums.update_resource_curriculum(existing, %{
          "grade_id" => grade_id,
          "subject_id" => subject_id
        })
        |> to_ok()
    end
  end

  defp ensure_resource_chapter(_resource_id, nil), do: :ok
  defp ensure_resource_chapter(_resource_id, ""), do: :ok

  defp ensure_resource_chapter(resource_id, chapter_id) do
    case ResourceChapters.get_resource_chapter_by_resource_id_and_chapter_id(
           resource_id,
           chapter_id
         ) do
      nil ->
        ResourceChapters.create_resource_chapter(%{
          "resource_id" => resource_id,
          "chapter_id" => chapter_id
        })
        |> to_ok()

      _ ->
        :ok
    end
  end

  defp ensure_resource_topic(_resource_id, nil), do: :ok
  defp ensure_resource_topic(_resource_id, ""), do: :ok

  defp ensure_resource_topic(resource_id, topic_id) do
    case ResourceTopics.get_resource_topic_by_resource_id_and_topic_id(resource_id, topic_id) do
      nil ->
        ResourceTopics.create_resource_topic(%{
          "resource_id" => resource_id,
          "topic_id" => topic_id
        })
        |> to_ok()

      _ ->
        :ok
    end
  end

  defp to_ok({:ok, _}), do: :ok
  defp to_ok({:error, changeset}), do: {:error, ChangesetFormatter.format_errors(changeset)}

  defp process_alumni_record(record) do
    student_identifier = Map.get(record, "student_id")

    with {:ok, student_pk} <- get_or_create_student_pk(record, student_identifier) do
      create_or_update_alumni(student_pk, record)
    end
  end

  defp get_or_create_student_pk(_record, student_identifier)
       when is_nil(student_identifier) or student_identifier == "" do
    {:error, "student_id is required for alumni addition"}
  end

  defp get_or_create_student_pk(record, student_identifier) do
    case Users.get_student_by_student_id(student_identifier) do
      nil ->
        case Users.create_student_with_user(record) do
          {:ok, %Dbservice.Users.Student{id: student_pk}} -> {:ok, student_pk}
          {:error, reason} -> {:error, reason}
        end

      %Dbservice.Users.Student{id: student_pk} ->
        {:ok, student_pk}
    end
  end

  defp create_or_update_alumni(student_pk, record) do
    attrs = Map.put(record, "student_id", student_pk)

    case Dbservice.Alumnis.get_alumni_by_student_id(student_pk) do
      nil -> Dbservice.Alumnis.create_alumni(attrs)
      %Dbservice.Alumnis.Alumni{} = existing -> Dbservice.Alumnis.update_alumni(existing, attrs)
    end
  end

  defp process_teacher_batch_assignment_record(record) do
    DataImport.TeacherBatchAssignment.process_teacher_batch_assignment(record)
  end

  defp process_batch_id_update_record(record) do
    DataImport.GroupUpdateProcessor.process_batch_id_update(record)
  end

  defp process_school_update_record(record) do
    DataImport.GroupUpdateProcessor.process_school_update(record)
  end

  defp process_grade_update_record(record) do
    DataImport.GroupUpdateProcessor.process_grade_update(record)
  end

  defp process_auth_group_update_record(record) do
    DataImport.GroupUpdateProcessor.process_auth_group_update(record)
  end

  defp count_total_rows(filename, start_row) do
    path = Path.join(["priv", "static", "uploads", filename])

    try do
      count =
        path
        |> File.stream!()
        |> CSV.decode!(
          separator: ?,,
          escape_character: ?",
          # This consumes row 1 as headers
          headers: true,
          validate_row_length: false,
          escape_max_lines: 2
        )
        # At this point, index 1 = row 2, index 2 = row 3, etc.
        |> Stream.with_index(1)
        # Filter to only count rows from start_row onward
        |> Stream.filter(fn {_record, index} ->
          # If start_row is 2, we want index >= 1 (all rows)
          # If start_row is 669, we want index >= 668 (skip first 667 data rows)
          index >= start_row - 1
        end)
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

  defp update_import_progress(import_record, index) do
    # index is now the processing index (1, 2, 3...) which directly represents processed rows
    processed_rows = index

    update_params = %{processed_rows: processed_rows}

    DataImport.update_import(import_record, update_params)

    # Broadcast progress update
    Phoenix.PubSub.broadcast(
      Dbservice.PubSub,
      "imports",
      {:import_updated, import_record.id}
    )
  end

  # Format error message based on error type
  defp format_error_message(%Ecto.Changeset{} = changeset, csv_row_number) do
    ChangesetFormatter.format_errors_with_row(changeset, csv_row_number)
  end

  defp format_error_message(error, csv_row_number) do
    "Row #{csv_row_number}: #{inspect(error)}"
  end

  defp finalize_import(import_record, records) do
    # Check if import was stopped during processing
    current_import = DataImport.get_import!(import_record.id)

    if current_import.status == "stopped" do
      # Import was halted, don't mark as completed
      {:ok, records}
    else
      total_records = length(records)

      DataImport.complete_import(
        import_record.id,
        total_records
      )

      {:ok, records}
    end
  end

  defp handle_import_error(import_record, reason) do
    DataImport.fail_import(
      import_record.id,
      reason
    )

    {:error, reason}
  end
end
