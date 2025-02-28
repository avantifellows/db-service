defmodule Dbservice.DataImport do
  @moduledoc """
  The DataImport context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.DataImport.Import
  alias Dbservice.DataImport.ImportWorker

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

  def start_import(%{"sheet_url" => url, "type" => type}) when url != "" do
    case download_google_sheet(url) do
      {:ok, filename} ->
        {:ok, import_record} =
          create_import(%{
            filename: filename,
            status: "pending",
            type: type,
            total_rows: 0,
            processed_rows: 0
          })

        %{id: import_record.id}
        |> ImportWorker.new()
        |> Oban.insert()

        {:ok, import_record}

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
          Logger.warn("Failed to delete import file #{path}: #{inspect(reason)}")
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

    # Update the import record with completion status
    {:ok, updated_import} =
      update_import(import_record, %{
        status: "completed",
        processed_rows: total_rows,
        total_rows: total_rows
      })

    # Clean up the file
    cleanup_import_file(updated_import)

    {:ok, updated_import}
  end

  @doc """
  Marks an import as failed and cleans up the file.
  """
  def fail_import(import_id, reason) do
    import_record = get_import!(import_id)

    # Update the import record with failure status
    {:ok, updated_import} =
      update_import(import_record, %{
        status: "failed",
        error_message: reason
      })

    # Clean up the file
    cleanup_import_file(updated_import)

    {:ok, updated_import}
  end

  defp download_google_sheet(url) do
    case extract_sheet_id(url) do
      sheet_id when is_binary(sheet_id) ->
        with {:ok, content} <- fetch_google_sheet(sheet_id),
             {:ok, filename} <- save_csv_file(content) do
          {:ok, filename}
        end

      error ->
        {:error, "Invalid sheet ID: #{inspect(error)}"}
    end
  end

  defp fetch_google_sheet(sheet_id) do
    csv_url =
      "https://docs.google.com/spreadsheets/d/#{sheet_id}/export?format=csv&id=#{sheet_id}"

    headers = [{"User-Agent", "Mozilla/5.0"}, {"Accept", "text/csv,application/csv"}]

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

  defp extract_sheet_id(url) do
    cond do
      Regex.match?(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url) ->
        [[_, sheet_id]] = Regex.scan(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url)
        sheet_id

      Regex.match?(~r/id=([a-zA-Z0-9-_]+)/, url) ->
        [[_, sheet_id]] = Regex.scan(~r/id=([a-zA-Z0-9-_]+)/, url)
        sheet_id

      true ->
        String.trim(url)
    end
  end
end
