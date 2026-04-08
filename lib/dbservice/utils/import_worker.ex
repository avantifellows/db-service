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
  alias Dbservice.Utils.Util
  alias Dbservice.Colleges
  alias Dbservice.Branches
  alias Dbservice.Chapters
  alias Dbservice.Subjects
  alias Dbservice.Curriculums
  alias Dbservice.Topics
  alias Dbservice.TopicCurriculums
  alias Dbservice.Purposes
  alias Dbservice.Resources
  alias Dbservice.ResourceCurriculums
  alias Dbservice.ResourceChapters
  alias Dbservice.ResourceTopics
  alias Dbservice.AuthGroups
  alias Dbservice.Groups
  alias Dbservice.Products
  alias Dbservice.Programs
  alias Dbservice.Batches

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
      "topic_addition" => &process_topic_record/1,
      "auth_group_addition" => &process_auth_group_addition_record/1,
      "product_addition" => &process_product_addition_record/1,
      "program_addition" => &process_program_addition_record/1,
      "batch_addition" => &process_batch_addition_record/1,
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
      |> add_resource_id_from_code_for_topic(import_type, row_number)
      |> add_product_id(row_number)
      |> add_program_id(row_number)
      |> add_auth_group_id_batch(row_number)
      |> add_parent_batch_id(row_number)
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
    apply_grade_id_to_record(record, Map.get(record, "grade"), row_number)
  end

  defp apply_grade_id_to_record(record, nil, _row_number), do: record
  defp apply_grade_id_to_record(record, "", _row_number), do: record

  defp apply_grade_id_to_record(record, grade, row_number) do
    try do
      put_grade_id_if_found(record, grade)
    rescue
      error ->
        reraise "Failed to lookup grade '#{grade}' on row #{row_number}: #{Exception.message(error)}",
                __STACKTRACE__
    end
  end

  defp put_grade_id_if_found(record, grade) do
    grade_number = parse_grade_number(grade)
    grade_id = grade_id_from_parsed_number(grade_number)
    if grade_id, do: Map.put(record, "grade_id", grade_id), else: record
  end

  defp grade_id_from_parsed_number(nil), do: nil

  defp grade_id_from_parsed_number(num) do
    case Grades.get_grade_by_number(num) do
      %Dbservice.Grades.Grade{} = g -> g.id
      {:ok, g} -> g.id
      _ -> nil
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

      value when is_binary(value) ->
        value = String.trim(value)
        if value == "", do: record, else: do_add_curriculum_ids(record, value, row_number)

      _ ->
        record
    end
  end

  defp do_add_curriculum_ids(record, value, row_number) do
    names =
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    ids =
      Enum.reduce_while(names, [], fn name, acc ->
        case Curriculums.get_curriculum_by_name(name) do
          nil -> {:halt, {:error, name}}
          curriculum -> {:cont, acc ++ [curriculum.id]}
        end
      end)

    case ids do
      {:error, bad_name} ->
        reraise_msg =
          "Failed to lookup curriculum '#{bad_name}' on row #{row_number}: curriculum not found in database"

        raise bad_name <> " — " <> reraise_msg

      resolved_ids when is_list(resolved_ids) ->
        record
        |> Map.put("curriculum_ids", resolved_ids)
        |> Map.put("curriculum_id", List.first(resolved_ids))
    end
  rescue
    error ->
      reraise "Failed to lookup curriculum on row #{row_number}: #{Exception.message(error)}",
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

  defp add_resource_id_from_code_for_topic(record, "topic_addition", row_number) do
    case Map.get(record, "code") do
      nil ->
        record

      "" ->
        record

      code when is_binary(code) ->
        code = String.trim(code)

        case Resources.get_resource_by_code(code) do
          nil -> record
          resource -> Map.put(record, "resource_id", resource.id)
        end

      _ ->
        record
    end
  rescue
    error ->
      reraise "Failed to lookup resource by code on row #{row_number}: #{Exception.message(error)}",
              __STACKTRACE__
  end

  defp add_resource_id_from_code_for_topic(record, _import_type, _row_number), do: record

  defp add_product_id(record, row_number) do
    case Map.get(record, "product_code") do
      nil ->
        record

      "" ->
        record

      code when is_binary(code) ->
        code = String.trim(code)
        if code == "", do: record, else: do_add_product_id(record, code, row_number)

      _ ->
        record
    end
  end

  defp do_add_product_id(record, code, _row_number) do
    case Products.get_product_by_code(code) do
      nil -> record
      product -> Map.put(record, "product_id", product.id)
    end
  end

  defp add_program_id(record, row_number) do
    case Map.get(record, "program_name") do
      nil ->
        record

      "" ->
        record

      name when is_binary(name) ->
        name = String.trim(name)
        if name == "", do: record, else: do_add_program_id(record, name, row_number)

      _ ->
        record
    end
  end

  defp do_add_program_id(record, name, _row_number) do
    case Programs.get_program_by_name(name) do
      nil -> record
      program -> Map.put(record, "program_id", program.id)
    end
  end

  defp add_auth_group_id_batch(record, row_number) do
    case Map.get(record, "auth_group") do
      nil ->
        record

      "" ->
        record

      name when is_binary(name) ->
        name = String.trim(name)
        if name == "", do: record, else: do_add_auth_group_id_batch(record, name, row_number)

      _ ->
        record
    end
  end

  defp do_add_auth_group_id_batch(record, name, _row_number) do
    case AuthGroups.get_auth_group_by_name(name) do
      nil -> record
      auth_group -> Map.put(record, "auth_group_id", auth_group.id)
    end
  end

  defp add_parent_batch_id(record, row_number) do
    case Map.get(record, "parent_batch_id") do
      nil ->
        record

      "" ->
        record

      batch_id when is_binary(batch_id) ->
        batch_id = String.trim(batch_id)
        if batch_id == "", do: record, else: do_add_parent_batch_id(record, batch_id, row_number)

      _ ->
        record
    end
  end

  defp do_add_parent_batch_id(record, batch_id, _row_number) do
    case Batches.get_batch_by_batch_id_nil(batch_id) do
      nil -> record
      parent_batch -> Map.put(record, "parent_id", parent_batch.id)
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

  defp process_topic_record(record) do
    topic_code = trim_optional(record["topic_code"])
    topic_name = trim_optional(record["topic_name"])
    curriculum_ids = record["curriculum_ids"]
    chapter_id = record["chapter_id"]
    resource_id = record["resource_id"]

    cond do
      is_nil(topic_code) or is_nil(topic_name) ->
        {:ok, :skipped_topic_row}

      is_nil(curriculum_ids) or curriculum_ids == [] ->
        {:error,
         "Could not resolve curriculum for row (topicCode: #{topic_code}). Ensure curriculum value exists."}

      true ->
        attrs =
          %{
            "code" => topic_code,
            "name" => build_topic_name_array(topic_name)
          }
          |> maybe_put("chapter_id", chapter_id)

        with {:ok, topic} <- create_or_update_topic(attrs, topic_code),
             :ok <- ensure_topic_curriculums(topic.id, curriculum_ids),
             :ok <- ensure_topic_resource(topic.id, resource_id) do
          {:ok, topic}
        end
    end
  end

  defp trim_optional(nil), do: nil
  defp trim_optional(""), do: nil

  defp trim_optional(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp trim_optional(value), do: value

  defp build_topic_name_array(nil), do: [%{"lang_code" => "en", "topic" => ""}]
  defp build_topic_name_array(""), do: [%{"lang_code" => "en", "topic" => ""}]

  defp build_topic_name_array(topic_name) when is_binary(topic_name),
    do: [%{"lang_code" => "en", "topic" => topic_name}]

  defp create_or_update_topic(attrs, topic_code) do
    case Topics.get_topic_by_code(topic_code) do
      nil -> Topics.create_topic(attrs)
      existing -> Topics.update_topic(existing, attrs)
    end
  end

  defp ensure_topic_curriculums(topic_id, curriculum_ids) do
    Enum.reduce_while(curriculum_ids, :ok, fn cid, :ok ->
      case ensure_topic_curriculum(topic_id, cid) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp ensure_topic_curriculum(topic_id, curriculum_id) do
    case TopicCurriculums.get_topic_curriculum_by_topic_id_and_curriculum_id(
           topic_id,
           curriculum_id
         ) do
      nil ->
        TopicCurriculums.create_topic_curriculum(%{
          "topic_id" => topic_id,
          "curriculum_id" => curriculum_id
        })
        |> to_ok()

      _ ->
        :ok
    end
  end

  defp ensure_topic_resource(_topic_id, nil), do: :ok
  defp ensure_topic_resource(_topic_id, ""), do: :ok

  defp ensure_topic_resource(topic_id, resource_id) do
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

  defp process_auth_group_addition_record(record) do
    with {:ok, name} <- validate_auth_group_name(record["name"]),
         attrs <- build_auth_group_attrs(record, name),
         {:ok, ag} <- create_or_update_auth_group(name, attrs) do
      {:ok, ag}
    else
      {:error, %Ecto.Changeset{} = cs} -> {:error, ChangesetFormatter.format_errors(cs)}
      {:error, msg} when is_binary(msg) -> {:error, msg}
      {:error, other} -> {:error, inspect(other)}
    end
  end

  defp validate_auth_group_name(nil), do: {:error, "Name is required for auth group addition"}

  defp validate_auth_group_name(name) when is_binary(name) do
    if String.trim(name) == "",
      do: {:error, "Name is required for auth group addition"},
      else: {:ok, String.trim(name)}
  end

  defp validate_auth_group_name(_), do: {:error, "Name is required for auth group addition"}

  defp build_auth_group_attrs(record, name) do
    input_schema = build_auth_group_input_schema(record)
    locale_data = parse_auth_group_locale_data(Map.get(record, "auth_group_locale_data_raw"))
    locale = record["locale"] |> auth_group_trim_or_nil()

    %{"name" => name}
    |> maybe_put_auth_group_field("input_schema", input_schema)
    |> maybe_put_auth_group_field("locale", locale)
    |> maybe_put_auth_group_field("locale_data", locale_data)
  end

  defp create_or_update_auth_group(name, attrs) do
    case AuthGroups.get_auth_group_by_name(name) do
      nil -> AuthGroups.create_auth_group_from_import(attrs)
      existing -> update_auth_group_and_maybe_users(existing, attrs)
    end
  end

  defp update_auth_group_and_maybe_users(existing, attrs) do
    case AuthGroups.update_auth_group(existing, attrs) do
      {:ok, ag} ->
        maybe_update_users_for_auth_group(ag.id)
        {:ok, ag}

      err ->
        err
    end
  end

  defp maybe_update_users_for_auth_group(auth_group_id) do
    if Groups.get_group_by_child_id_and_type(auth_group_id, "auth_group") do
      _ = Util.update_users_for_group(auth_group_id, "auth_group")
    end
  end

  defp build_auth_group_input_schema(record) do
    %{}
    |> put_input_schema_if_present("images", record["auth_group_images"])
    |> put_input_schema_if_present("user_type", record["auth_group_user_type"])
    |> put_input_schema_if_present("auth_type", record["auth_group_auth_type"])
    |> put_input_schema_if_present("default_locale", record["auth_group_default_locale"])
    |> put_input_schema_if_present("tech_pm", record["auth_group_tech_pm"])
  end

  defp put_input_schema_if_present(map, _key, nil), do: map
  defp put_input_schema_if_present(map, _key, ""), do: map

  defp put_input_schema_if_present(map, key, v) when is_binary(v) do
    v = String.trim(v)
    if v == "", do: map, else: Map.put(map, key, v)
  end

  defp put_input_schema_if_present(map, key, v), do: Map.put(map, key, v)

  defp parse_auth_group_locale_data(nil), do: nil
  defp parse_auth_group_locale_data(""), do: nil

  defp parse_auth_group_locale_data(raw) when is_binary(raw) do
    raw = String.trim(raw)

    case Jason.decode(raw) do
      {:ok, %{} = m} -> m
      {:ok, _} -> %{"_value" => raw}
      {:error, _} -> %{"_raw" => raw}
    end
  end

  defp parse_auth_group_locale_data(_), do: nil

  defp auth_group_trim_or_nil(nil), do: nil

  defp auth_group_trim_or_nil(s) when is_binary(s) do
    t = String.trim(s)
    if t == "", do: nil, else: t
  end

  defp maybe_put_auth_group_field(attrs, _key, nil), do: attrs
  defp maybe_put_auth_group_field(attrs, "input_schema", m) when map_size(m) == 0, do: attrs
  defp maybe_put_auth_group_field(attrs, key, v), do: Map.put(attrs, key, v)

  defp process_product_addition_record(record) do
    name = record["name"] |> trim_str()
    code = record["code"] |> trim_str()

    if is_nil(name) or name == "" do
      {:error, "Name is required for product addition"}
    else
      attrs =
        %{"name" => name}
        |> maybe_put_product("code", code)
        |> maybe_put_product("mode", record["mode"] |> trim_str())
        |> maybe_put_product("model", record["model"] |> trim_str())
        |> maybe_put_product("tech_modules", record["tech_modules"] |> trim_str())
        |> maybe_put_product("type", record["type"] |> trim_str())
        |> maybe_put_product("led_by", record["led_by"] |> trim_str())
        |> maybe_put_product("goal", record["goal"] |> trim_str())

      case Products.get_product_by_name_and_code(name, code) do
        nil ->
          Products.create_product_from_import(attrs)

        existing ->
          Products.update_product(existing, attrs)
      end
      |> case do
        {:ok, product} -> {:ok, product}
        {:error, %Ecto.Changeset{} = cs} -> {:error, ChangesetFormatter.format_errors(cs)}
        {:error, other} -> {:error, inspect(other)}
      end
    end
  end

  defp process_program_addition_record(record) do
    name = record["name"] |> trim_str()

    if is_nil(name) or name == "" do
      {:error, "Program Name is required for program addition"}
    else
      attrs =
        %{"name" => name}
        |> maybe_put_program("target_outreach", parse_int(record["target_outreach"]))
        |> maybe_put_program("donor", record["donor"] |> trim_str())
        |> maybe_put_program("state", record["state"] |> trim_str())
        |> maybe_put_program("product_id", record["product_id"])
        |> maybe_put_program("model", record["model"] |> trim_str())
        |> maybe_put_program("is_current", record["is_current"])

      case Programs.get_program_by_name(name) do
        nil ->
          Programs.create_program_from_import(attrs)

        existing ->
          Programs.update_program(existing, attrs)
      end
      |> case do
        {:ok, program} -> {:ok, program}
        {:error, %Ecto.Changeset{} = cs} -> {:error, ChangesetFormatter.format_errors(cs)}
        {:error, other} -> {:error, inspect(other)}
      end
    end
  end

  defp maybe_put_program(attrs, _key, nil), do: attrs
  defp maybe_put_program(attrs, _key, ""), do: attrs
  defp maybe_put_program(attrs, key, value), do: Map.put(attrs, key, value)

  defp process_batch_addition_record(record) do
    with {:ok, name} <- validate_batch_name(record["name"]),
         metadata <- batch_metadata_from_record(record),
         attrs <- build_batch_attrs(record, name, metadata),
         result <- create_or_update_batch(attrs) do
      format_batch_result(result)
    else
      {:error, msg} when is_binary(msg) -> {:error, msg}
    end
  end

  defp validate_batch_name(nil), do: {:error, "Name is required for batch addition"}

  defp validate_batch_name(name) when is_binary(name) do
    t = String.trim(name)
    if t == "", do: {:error, "Name is required for batch addition"}, else: {:ok, t}
  end

  defp validate_batch_name(_), do: {:error, "Name is required for batch addition"}

  defp batch_metadata_from_record(record) do
    case record["is_parent_batch"] do
      true -> %{"is_parent_batch" => true}
      false -> %{"is_parent_batch" => false}
      _ -> %{}
    end
  end

  defp build_batch_attrs(record, name, metadata) do
    metadata_value = if metadata != %{}, do: metadata, else: nil

    %{"name" => name}
    |> maybe_put_batch("batch_id", record["batch_id"] |> trim_str())
    |> maybe_put_batch("contact_hours_per_week", parse_int(record["contact_hours_per_week"]))
    |> maybe_put_batch("parent_id", record["parent_id"])
    |> maybe_put_batch("start_date", parse_date(record["start_date"]))
    |> maybe_put_batch("end_date", parse_date(record["end_date"]))
    |> maybe_put_batch("program_id", record["program_id"])
    |> maybe_put_batch("auth_group_id", record["auth_group_id"])
    |> maybe_put_batch("metadata", metadata_value)
  end

  defp create_or_update_batch(attrs) do
    existing = find_existing_batch(attrs["batch_id"])

    if existing,
      do: Batches.update_batch(existing, attrs),
      else: Batches.create_batch_from_import(attrs)
  end

  defp find_existing_batch(nil), do: nil
  defp find_existing_batch(""), do: nil

  defp find_existing_batch(batch_id) when is_binary(batch_id),
    do: Batches.get_batch_by_batch_id_nil(batch_id)

  defp find_existing_batch(_), do: nil

  defp format_batch_result({:ok, batch}), do: {:ok, batch}

  defp format_batch_result({:error, %Ecto.Changeset{} = cs}),
    do: {:error, ChangesetFormatter.format_errors(cs)}

  defp format_batch_result({:error, other}), do: {:error, inspect(other)}

  defp maybe_put_batch(attrs, _key, nil), do: attrs
  defp maybe_put_batch(attrs, _key, ""), do: attrs
  defp maybe_put_batch(attrs, key, value), do: Map.put(attrs, key, value)

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(n) when is_integer(n), do: n

  defp parse_int(s) when is_binary(s) do
    s = String.trim(s)

    case Integer.parse(s) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(%Date{} = d), do: d

  defp parse_date(s) when is_binary(s) do
    s = String.trim(s)

    case Date.from_iso8601(s) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil

  defp trim_str(nil), do: nil
  defp trim_str(s) when is_binary(s), do: String.trim(s)
  defp trim_str(s), do: s

  defp maybe_put_product(attrs, _key, nil), do: attrs
  defp maybe_put_product(attrs, _key, ""), do: attrs
  defp maybe_put_product(attrs, key, v), do: Map.put(attrs, key, v)

  defp process_resource_record(record) do
    case validate_resource_fields(record) do
      {:error, _} = error -> error
      :ok -> do_process_resource_record(record)
    end
  end

  defp validate_resource_fields(record) do
    code = record["code"]

    cond do
      blank?(record["resource_type"]) ->
        {:error, "resourceType is required for row (code: #{code})"}

      blank?(record["resource_link"]) ->
        {:error, "resourceLink is required for row (code: #{code})"}

      blank?(record["resource_name"]) ->
        {:error, "resourceName is required for row (code: #{code})"}

      is_nil(record["curriculum_ids"]) or record["curriculum_ids"] == [] ->
        {:error,
         "Could not resolve curriculum for row (code: #{code}). Ensure curriculum value exists."}

      true ->
        :ok
    end
  end

  defp do_process_resource_record(record) do
    name_array = build_resource_name_array(record["resource_name"])
    type_params = %{"src_link" => String.trim(record["resource_link"])}

    resource_attrs =
      %{
        "code" => record["code"],
        "name" => name_array,
        "type" => String.trim(record["resource_type"]),
        "type_params" => type_params
      }
      |> maybe_put("subtype", record["resource_subtype"])
      |> maybe_put("source", record["resource_source"])
      |> maybe_put("purpose_ids", record["purpose_ids"])

    topic_id = record["topic_id"]

    with {:ok, resource} <- create_or_update_resource(resource_attrs, record["code"]),
         :ok <-
           ensure_resource_curriculums(
             resource.id,
             record["curriculum_ids"],
             record["grade_id"],
             record["subject_id"]
           ),
         :ok <- maybe_ensure_resource_chapter(resource.id, record["chapter_id"], topic_id),
         :ok <- ensure_resource_topic(resource.id, topic_id) do
      {:ok, resource}
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

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

  defp ensure_resource_curriculums(_resource_id, _curriculum_ids, grade_id, _subject_id)
       when is_nil(grade_id) or grade_id == "",
       do: :ok

  defp ensure_resource_curriculums(resource_id, curriculum_ids, grade_id, subject_id) do
    Enum.reduce_while(curriculum_ids, :ok, fn cid, :ok ->
      case ensure_resource_curriculum(resource_id, cid, grade_id, subject_id) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
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

  defp maybe_ensure_resource_chapter(_resource_id, _chapter_id, topic_id)
       when not is_nil(topic_id) and topic_id != "",
       do: :ok

  defp maybe_ensure_resource_chapter(resource_id, chapter_id, _topic_id),
    do: ensure_resource_chapter(resource_id, chapter_id)

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
