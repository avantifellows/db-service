defmodule Dbservice.DataImport do
  @moduledoc """
  The DataImport context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.DataImport.Import
  alias Dbservice.DataImport.ImportWorker
  alias Dbservice.Constants.Mappings

  @doc """
  Returns a human-readable name for the import type.
  """
  def format_type_name("student"), do: "Student Addition"
  def format_type_name("student_update"), do: "Update Student Details"
  def format_type_name("batch_movement"), do: "Student Batch Movement"
  def format_type_name("teacher_batch_assignment"), do: "Teacher Batch Assignment"
  def format_type_name("teacher_addition"), do: "Teacher Addition"

  def format_type_name("update_incorrect_batch_id_to_correct_batch_id"),
    do: "Update Incorrect Batch ID to Correct Batch ID"

  def format_type_name("update_incorrect_school_to_correct_school"),
    do: "Update Incorrect School to Correct School"

  def format_type_name("update_incorrect_grade_to_correct_grade"),
    do: "Update Incorrect Grade to Correct Grade"

  def format_type_name("update_incorrect_auth_group_to_correct_auth_group"),
    do: "Update Incorrect Auth Group to Correct Auth Group"

  def format_type_name(type), do: String.capitalize(type)

  @doc """
  Returns the list of Import.
  ## Examples
      iex> list_imports()
      [%Import{}, ...]
  """
  def list_imports do
    Repo.all(from i in Import, order_by: [desc: i.inserted_at])
  end

  @doc """
  Gets a single Import.
  Raises `Ecto.NoResultsError` if the Import does not exist.
  ## Examples
      iex> get_import!(123)
      %Import{}
      iex> get_import!(456)
      ** (Ecto.NoResultsError)
  """
  def get_import!(id), do: Repo.get!(Import, id)

  @doc """
  Creates a import.
  ## Examples
      iex> create_import(%{field: value})
      {:ok, %Import{}}
      iex> create_import(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_import(attrs \\ %{}) do
    %Import{}
    |> Import.changeset(attrs)
    |> Repo.insert()
  end

  def change_import(%Import{} = import_record, attrs \\ %{}) do
    Import.changeset(import_record, attrs)
  end

  @doc """
  Updates a import.
  ## Examples
      iex> update_import(Import, %{field: new_value})
      {:ok, %Import{}}
      iex> update_import(Import, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """

  def update_import(%Import{} = data_import, attrs) do
    data_import
    |> Import.changeset(attrs)
    |> Repo.update()
  end

  def start_import(%{
        "sheet_url" => url,
        "type" => type,
        "start_row" => start_row
      })
      when url != "" do
    start_row = String.to_integer(start_row)

    case download_google_sheet(url) do
      {:ok, filename} ->
        # Validate CSV format and start row before creating import record
        case validate_csv_format(filename, type, start_row) do
          :ok ->
            {:ok, import_record} =
              create_import(%{
                filename: filename,
                status: "pending",
                type: type,
                total_rows: 0,
                processed_rows: 0,
                start_row: start_row
              })

            %{id: import_record.id}
            |> ImportWorker.new()
            |> Oban.insert()

            {:ok, import_record}

          {:error, reason} ->
            # Clean up the downloaded file if validation fails
            # Create a temporary import record structure for cleanup
            temp_import = %Import{filename: filename}
            cleanup_import_file(temp_import)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, "Failed to download sheet: #{reason}"}
    end
  end

  @doc """
  Deletes the CSV file associated with an import after processing is complete.
  Should be called from the ImportWorker after import is done.
  """
  def cleanup_import_file(%Import{} = import_record) do
    if import_record.filename do
      path = Path.join(["priv", "static", "uploads", import_record.filename])

      case File.rm(path) do
        :ok ->
          # Update the import record to indicate the file has been removed
          update_import(import_record, %{filename: nil})
          {:ok, "File deleted successfully"}

        {:error, reason} ->
          # Log the error but don't fail the import process
          require Logger
          Logger.warning("Failed to delete import file #{path}: #{inspect(reason)}")
          {:error, "Failed to delete file: #{inspect(reason)}"}
      end
    else
      {:ok, "No file to delete"}
    end
  end

  @doc """
  Completes an import process, updating its status and cleaning up the file.
  To be called when import is successfully finished.
  """
  def complete_import(import_id, total_rows) do
    import_record = get_import!(import_id)

    attrs =
      if import_record.status == "stopped" do
        %{processed_rows: total_rows}
      else
        %{
          status: "completed",
          processed_rows: total_rows,
          completed_at: DateTime.utc_now()
        }
      end

    {:ok, updated_import} = update_import(import_record, attrs)

    Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})
    cleanup_import_file(updated_import)

    {:ok, updated_import}
  end

  @doc """
  Marks an import as failed and cleans up the file.
  """
  def fail_import(import_id, reason) do
    import_record = get_import!(import_id)

    # Preserve existing error details and add the failure reason
    existing_error_details = import_record.error_details || []

    error_details =
      case existing_error_details do
        [] -> [%{error: reason}]
        _ -> existing_error_details
      end

    # Update the import record with failure status
    {:ok, updated_import} =
      update_import(import_record, %{
        status: "failed",
        error_details: error_details,
        completed_at: DateTime.utc_now()
      })

    # Broadcast failure update
    Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})

    # Clean up the file
    cleanup_import_file(updated_import)

    {:ok, updated_import}
  end

  @doc """
  Halts an import process, updating its status to stopped and cleaning up the file.
  """
  def halt_import(import_id) do
    import_record = get_import!(import_id)

    # Only allow halting if the import is currently processing or pending
    if import_record.status in ["processing", "pending"] do
      # Update the import record with stopped status
      {:ok, updated_import} =
        update_import(import_record, %{
          status: "stopped",
          completed_at: DateTime.utc_now()
        })

      # Broadcast halt update
      Phoenix.PubSub.broadcast(Dbservice.PubSub, "imports", {:import_updated, import_record.id})

      # Clean up the file
      cleanup_import_file(updated_import)

      {:ok, updated_import}
    else
      {:error, "Import cannot be halted. Current status: #{import_record.status}"}
    end
  end

  @doc """
  Validates the CSV file format based on the import type.
  Checks if the headers match the expected format and validates start row.
  """
  def validate_csv_format(filename, type, start_row \\ 2) do
    path = Path.join(["priv", "static", "uploads", filename])

    case File.read(path) do
      {:ok, content} ->
        validate_csv_content(content, type, start_row)

      {:error, reason} ->
        {:error, "Failed to read CSV file: #{inspect(reason)}"}
    end
  end

  # Extract CSV content validation to reduce nesting
  defp validate_csv_content(content, type, start_row) do
    lines = String.split(content, "\n")
    total_rows = Enum.count(lines, &(String.trim(&1) != ""))

    case validate_start_row(start_row, total_rows) do
      :ok ->
        validate_csv_headers(lines, type)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extract header validation to reduce nesting
  defp validate_csv_headers(lines, type) do
    case lines do
      [header_line | _] when header_line != "" ->
        headers = parse_header_line(header_line)
        validate_headers(headers, type)

      [] ->
        {:error, "CSV file is empty"}

      _ ->
        {:error, "CSV file has no valid header row"}
    end
  end

  # Extract header parsing logic
  defp parse_header_line(header_line) do
    header_line
    |> String.trim()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.replace(&1, "\"", ""))
    |> Enum.map(&String.trim/1)
  end

  # Private function to validate start row
  defp validate_start_row(start_row, total_rows) do
    cond do
      start_row <= 1 ->
        {:error, "Start row must be at least 2 (row 1 is reserved for headers)"}

      start_row - 1 > total_rows ->
        {:error,
         "Start row (#{start_row}) cannot be greater than total rows (#{total_rows}). Please enter a valid start row number."}

      start_row - 1 == total_rows ->
        {:error,
         "Start row (#{start_row}) is the last row. There must be at least one data row after the header row. Please enter a valid start row number."}

      true ->
        :ok
    end
  end

  # Private function to validate headers based on type
  defp validate_headers(headers, type) do
    required_headers = Mappings.get_required_headers(type)
    all_headers = Mappings.get_all_headers(type)

    validate_headers_against_schema(
      headers,
      required_headers,
      all_headers,
      format_type_name(type) <> " sheet"
    )
  end

  # Shared helper function for header validation
  defp validate_headers_against_schema(headers, required_headers, all_headers, sheet_type) do
    # Remove empty headers and normalize
    normalized_headers = Enum.reject(headers, &(&1 == ""))

    # Check if all required headers are present
    missing_required = required_headers -- normalized_headers
    # Check for extra headers (allow optional fields)
    extra_headers = normalized_headers -- all_headers

    if length(missing_required) > 0 or length(extra_headers) > 0 do
      {:error, "Invalid format for #{sheet_type}"}
    else
      :ok
    end
  end

  defp download_google_sheet(url) do
    case extract_sheet_info(url) do
      {:ok, sheet_id, gid} ->
        with {:ok, token} <- get_google_access_token(),
             {:ok, content} <- fetch_google_sheet(sheet_id, gid, token),
             {:ok, filename} <- save_csv_file(content) do
          {:ok, filename}
        else
          {:error, reason} -> {:error, "Failed to download or save file: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_google_access_token do
    case Goth.fetch(Dbservice.Goth) do
      {:ok, %Goth.Token{token: token}} -> {:ok, token}
      {:error, reason} -> {:error, "Failed to get Google OAuth token: #{inspect(reason)}"}
    end
  end

  defp fetch_google_sheet(sheet_id, gid, token) do
    # Build URL with gid parameter if provided
    csv_url =
      if gid do
        "https://docs.google.com/spreadsheets/d/#{sheet_id}/export?format=csv&id=#{sheet_id}&gid=#{gid}"
      else
        "https://docs.google.com/spreadsheets/d/#{sheet_id}/export?format=csv&id=#{sheet_id}"
      end

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"User-Agent", "Mozilla/5.0"},
      {"Accept", "text/csv,application/csv"}
    ]

    case HTTPoison.get(csv_url, headers, follow_redirect: true, max_redirects: 5) do
      {:ok, %{status_code: 200, body: content}} when byte_size(content) > 0 ->
        {:ok, content}

      {:ok, %{status_code: status_code}} ->
        {:error, "Unexpected status code: #{status_code}"}

      {:ok, %{body: ""}} ->
        {:error, "Received empty response"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  defp save_csv_file(content) do
    filename = "#{Ecto.UUID.generate()}.csv"
    path = Path.join(["priv", "static", "uploads", filename])

    File.mkdir_p!(Path.dirname(path))

    case File.write(path, content) do
      :ok -> validate_file(path, filename)
      {:error, reason} -> {:error, "Failed to write file: #{reason}"}
    end
  end

  defp validate_file(path, filename) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> {:ok, filename}
      _ -> {:error, "File was created but is empty"}
    end
  end

  defp extract_sheet_info(url) do
    # First extract the sheet ID
    sheet_id =
      cond do
        Regex.match?(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url) ->
          [[_, id]] = Regex.scan(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url)
          id

        Regex.match?(~r/id=([a-zA-Z0-9-_]+)/, url) ->
          [[_, id]] = Regex.scan(~r/id=([a-zA-Z0-9-_]+)/, url)
          id

        true ->
          String.trim(url)
      end

    # Extract gid - prefer query parameter over fragment
    gid = extract_gid_from_url(url)

    if is_binary(sheet_id) and byte_size(sheet_id) > 0 do
      {:ok, sheet_id, gid}
    else
      {:error, "Invalid sheet ID: #{inspect(sheet_id)}"}
    end
  end

  # Extract gid from URL, safely handling cases with multiple gid occurrences
  defp extract_gid_from_url(url) do
    # First check query parameters (after ? and before #)
    query_gid =
      case Regex.run(~r/[?&]gid=([0-9]+)/, url) do
        [_, gid] -> gid
        _ -> nil
      end

    # If no query gid, check fragment (after #)
    fragment_gid =
      case Regex.run(~r/#.*gid=([0-9]+)/, url) do
        [_, gid] -> gid
        _ -> nil
      end

    # Prefer query parameter gid if available, otherwise use fragment gid
    query_gid || fragment_gid
  end

  @doc """
  Generates a CSV template for the specified import type with proper headers.
  """
  def generate_csv_template(import_type) do
    headers =
      import_type
      |> Mappings.get_all_headers()
      |> Enum.sort()

    # Create CSV content with headers only
    headers
    |> Enum.join(",")
    |> Kernel.<>("\n")
  end

  @doc """
  Gets the filename for a CSV template download.
  """
  def get_template_filename(import_type) do
    "#{import_type}_template.csv"
  end
end
