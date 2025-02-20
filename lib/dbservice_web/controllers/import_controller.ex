defmodule DbserviceWeb.ImportController do
  use DbserviceWeb, :controller
  alias Dbservice.DataImport
  alias Dbservice.DataImport.ImportWorker

  def index(conn, _params) do
    imports = DataImport.list_imports()
    render(conn, "index.html", imports: imports)
  end

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"import" => %{"sheet_url" => url, "type" => type}}) when url != "" do
    case download_google_sheet(url) do
      {:ok, filename} ->
        # Create import record and process
        {:ok, import_record} =
          DataImport.create_import(%{
            filename: filename,
            status: "pending",
            type: type,
            total_rows: 0,
            processed_rows: 0
          })

        # Enqueue the import job
        %{id: import_record.id}
        |> ImportWorker.new()
        |> Oban.insert()

        conn
        |> put_flash(:info, "Import started. You can track its progress here.")
        |> redirect(to: Routes.import_path(conn, :show, import_record))

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to download sheet: #{reason}")
        |> render("new.html")
    end
  end

  defp download_google_sheet(url) do
    # Extract sheet ID from URL
    sheet_id = extract_sheet_id(url)

    # Convert to CSV download URL - using the export API with key parameters
    csv_url = "https://docs.google.com/spreadsheets/d/#{sheet_id}/export?format=csv&id=#{sheet_id}"

    # Set up headers to mimic browser request
    headers = [
      {"User-Agent", "Mozilla/5.0"},
      {"Accept", "text/csv,application/csv"}
    ]

    # Download and save
    filename = "#{Ecto.UUID.generate()}.csv"
    path = Path.join(["priv", "static", "uploads", filename])

    # Make request with headers and handle redirects
    case HTTPoison.get(csv_url, headers, [follow_redirect: true, max_redirects: 5]) do
      {:ok, %{status_code: 200, body: content}} when byte_size(content) > 0 ->
        # Ensure directory exists
        File.mkdir_p!(Path.dirname(path))
        # Write file
        case File.write(path, content) do
          :ok ->
            # Verify file was written successfully
            case File.stat(path) do
              {:ok, %{size: size}} when size > 0 ->
                {:ok, filename}
              _ ->
                {:error, "File was created but is empty"}
            end
          {:error, reason} ->
            {:error, "Failed to write file: #{reason}"}
        end

      {:ok, %{status_code: status_code}} ->
        {:error, "Unexpected status code: #{status_code}"}

      {:ok, %{body: ""}} ->
        {:error, "Received empty response"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{reason}"}
    end
  end

  def show(conn, %{"id" => id}) do
    import_record = DataImport.get_import!(id)
    render(conn, "show.html", import: import_record)
  end

  defp extract_sheet_id(url) do
    cond do
      # Format: https://docs.google.com/spreadsheets/d/SHEET_ID/edit#gid=0
      Regex.match?(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url) ->
        [[_, sheet_id]] = Regex.scan(~r/spreadsheets\/d\/([a-zA-Z0-9-_]+)/, url)
        sheet_id

      # Format: https://drive.google.com/open?id=SHEET_ID
      Regex.match?(~r/id=([a-zA-Z0-9-_]+)/, url) ->
        [[_, sheet_id]] = Regex.scan(~r/id=([a-zA-Z0-9-_]+)/, url)
        sheet_id

      true ->
        # If no patterns match, return the original string (assuming it might be a direct ID)
        url |> String.trim()
    end
  end
end
