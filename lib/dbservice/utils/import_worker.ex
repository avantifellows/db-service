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
    total_rows = count_total_rows(import_record.filename, import_record.start_row || 2) + 1

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

      grade ->
        try do
          case Grades.get_grade_by_number(grade) do
            %Dbservice.Grades.Grade{} = grade_record ->
              Map.put(record, "grade_id", grade_record.id)

            {:ok, grade_record} ->
              Map.put(record, "grade_id", grade_record.id)

            _ ->
              record
          end
        rescue
          error ->
            # Preserve original stacktrace while adding context
            reraise "Failed to lookup grade '#{grade}' on row #{row_number}: #{Exception.message(error)}",
                    __STACKTRACE__
        end
    end
  end

  defp add_subject_id(record, row_number) do
    case Map.get(record, "subject") do
      nil ->
        record

      subject_name ->
        try do
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
        # index 1 corresponds to first data row (after header)
        |> Stream.with_index(1)
        |> Stream.filter(fn {_record, index} -> index >= start_row - 1 end)
        |> Stream.map(fn {record, index} ->
          # Compute actual CSV row number (header is row 1)
          csv_row_number = index + 1

          try do
            {field_extractor_fn.({record, csv_row_number}), index}
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
    # Calculate actual CSV row number: index is 1-based for filtered data rows
    # CSV row = index + start_row - 1 (since index 1 = first data row = start_row)
    start_row = import_record.start_row || 2
    csv_row_number = index + start_row - 1

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
    # Calculate actual CSV row number
    start_row = import_record.start_row || 2
    csv_row_number = index + start_row - 1

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
    with {:ok, _} <- validate_student_identifiers(record),
         {:ok, result} <- process_student(record) do
      result
    end
  end

  defp validate_student_identifiers(record) do
    student_id = record["student_id"]
    apaar_id = record["apaar_id"]

    if nil_or_empty?(student_id) and nil_or_empty?(apaar_id) do
      {:error, "Either student_id or apaar_id is required for student addition"}
    else
      {:ok, :valid}
    end
  end

  defp process_student(record) do
    case Users.get_student_by_id_or_apaar_id(record) do
      nil -> create_student(record)
      existing_student -> handle_existing_student(existing_student, record)
    end
  end

  defp create_student(record) do
    with {:ok, student} <- Users.create_student_with_user(record),
         student <- Dbservice.Repo.preload(student, [:user]),
         {:ok, _} <- DataImport.StudentEnrollment.create_enrollments(student.user, record) do
      {:ok, {:ok, student}}
    else
      {:error, _} = error -> {:ok, error}
    end
  end

  defp handle_existing_student(existing_student, record) do
    user = Users.get_user!(existing_student.user_id)
    auth_groups = Dbservice.GroupUsers.get_group_user_by_user_id_and_type(user.id, "auth_group")

    auth_group_name =
      case auth_groups do
        [%{group: %{id: _, type: _, child_id: child_id}} | _] ->
          case Dbservice.AuthGroups.get_auth_group!(child_id) do
            %{name: name} -> name
            _ -> "unknown"
          end

        _ ->
          "unknown"
      end

    error_message = build_duplicate_error_message(record, existing_student, auth_group_name)
    {:ok, {:error, error_message}}
  end

  defp build_duplicate_error_message(record, existing_student, auth_group_name) do
    cond do
      not nil_or_empty?(record["student_id"]) ->
        "Student already exists with student_id: #{existing_student.student_id} and auth_group: #{auth_group_name}"

      not nil_or_empty?(record["apaar_id"]) ->
        "Student already exists with apaar_id: #{existing_student.apaar_id} and auth_group: #{auth_group_name}"

      true ->
        "Student already exists with auth_group: #{auth_group_name}"
    end
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

  defp update_import_progress(import_record, index) do
    # Calculate how many data rows we've processed successfully
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
