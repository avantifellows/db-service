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
  alias Dbservice.Constants.Mappings
  alias Dbservice.Users
  alias Dbservice.Grades
  alias Dbservice.Services.StudentUpdateService

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
      "student" -> process_import(import_record, &process_student_record/1, true)
      "student_update" -> process_import(import_record, &process_student_update_record/1, false)
      "batch_movement" -> process_import(import_record, &process_batch_movement_record/1, true)
      _ -> {:error, "Unsupported import type"}
    end
  end

  # Generic import processing function
  defp process_import(import_record, record_processor_fn, halt_on_error?) do
    path = Path.join(["priv", "static", "uploads", import_record.filename])
    start_row = import_record.start_row || 2

    case parse_csv_records(path, start_row, import_record.type) do
      {:ok, parsed_records} ->
        try do
          case process_parsed_records(
                 parsed_records,
                 import_record,
                 record_processor_fn,
                 halt_on_error?
               ) do
            {:ok, processed_records} -> finalize_import(import_record, processed_records)
            {:error, reason} -> handle_import_error(import_record, reason)
          end
        rescue
          e -> handle_import_error(import_record, Exception.message(e))
        end

      {:error, reason} ->
        handle_import_error(import_record, reason)
    end
  end

  # Generic CSV parsing function
  defp parse_csv_records(path, start_row, import_type) do
    field_extractor_fn = get_field_extractor_fn(import_type)

    parse_csv_records_with_extractor(path, start_row, field_extractor_fn)
  end

  # Unified field extractor function for all import types
  defp get_field_extractor_fn(import_type) do
    fn record ->
      record
      |> extract_field_mappings(import_type)
      |> map_boolean_fields(import_type)
      |> add_grade_id()
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
        |> Stream.with_index(1)
        |> Stream.filter(fn {_record, index} -> index >= start_row - 1 end)
        |> Stream.map(fn {record, index} -> {field_extractor_fn.(record), index} end)
        |> Enum.to_list()

      {:ok, records}
    rescue
      _e in CSV.StrayEscapeCharacterError ->
        {:error, "CSV parsing failed: Stray escape character. Check file formatting."}

      error ->
        {:error, "Unexpected error parsing CSV: #{inspect(error)}"}
    end
  end

  # Generic record processing with configurable error handling
  defp process_parsed_records(records, import_record, record_processor_fn, halt_on_error?) do
    initial_acc = {:ok, []}

    result = Enum.reduce_while(records, initial_acc, fn {record, index}, {:ok, processed_records} ->
      handle_record_processing(record, index, import_record, record_processor_fn, halt_on_error?, processed_records)
    end)

    case result do
      {:ok, processed_records} -> {:ok, Enum.reverse(processed_records)}
      error -> error
    end
  end

  # Helper function to handle individual record processing within the reduce_while loop
  defp handle_record_processing(record, index, import_record, record_processor_fn, halt_on_error?, processed_records) do
    case process_single_record(record, index, import_record, record_processor_fn) do
      {:ok, result} ->
        {:cont, {:ok, [result | processed_records]}}

      {:error, reason} ->
        handle_record_error(index, reason, halt_on_error?, import_record, processed_records)
    end
  end

  # Helper function to handle errors during record processing
  defp handle_record_error(index, reason, halt_on_error?, import_record, processed_records) do
    if halt_on_error? do
      # Halt the entire import process if any row fails
      {:halt, {:error, "Error processing row #{index}: #{reason}"}}
    else
      # Continue processing other records even if one fails
      update_import_progress(import_record, index, :error, reason)
      {:cont, {:ok, processed_records}}
    end
  end

  # Generic single record processing
  defp process_single_record(record, index, import_record, record_processor_fn) do
    try do
      case record_processor_fn.(record) do
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

  # Record processor functions for each import type
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

  defp process_student_update_record(record) do
    student_id = record["student_id"]

    if is_nil(student_id) or student_id == "" do
      {:error, "student_id is required for student updates"}
    else
      StudentUpdateService.update_student_by_id(student_id, record)
    end
  end

  defp process_batch_movement_record(record) do
    DataImport.BatchMovement.process_batch_movement(record)
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
end
