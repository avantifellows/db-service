defmodule DbserviceWeb.ImportController do
  use DbserviceWeb, :controller
  alias Dbservice.DataImport
  import Plug.Conn

  def admin_auth(conn, _params) do
    # This endpoint requires basic auth via the dashboard_auth pipeline
    # If auth is successful, set session variable and redirect back to imports/new
    conn
    |> put_session("admin_authenticated", true)
    |> redirect(to: ~p"/imports/new")
  end

  def create_dropout_import(conn, params) do
    # Extract import params from nested "import" key
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "dropout")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Dropout import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end

  def create_re_enrollment_import(conn, params) do
    # Extract import params from nested "import" key
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "re_enrollment")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Re-enrollment import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end

  def create_remove_wrong_enrollment_records_import(conn, params) do
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "remove_wrong_enrollment_records")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Remove Wrong Enrollment Records import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end
end
