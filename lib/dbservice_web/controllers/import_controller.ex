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

  def create_auth_group_import(conn, params) do
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "auth_group_addition")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Auth group import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end

  def create_product_import(conn, params) do
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "product_addition")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Product import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end

  def create_program_import(conn, params) do
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "program_addition")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Program import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end

  def create_batch_import(conn, params) do
    import_params =
      params
      |> Map.get("import", %{})
      |> Map.put("type", "batch_addition")

    case DataImport.start_import(import_params) do
      {:ok, _import} ->
        conn
        |> put_flash(
          :info,
          "Batch import queued successfully! Processing will begin shortly. Check the imports page for progress updates."
        )
        |> redirect(to: ~p"/imports")

      {:error, reason} ->
        conn
        |> put_flash(:error, "Import failed: #{reason}")
        |> redirect(to: ~p"/imports/new")
    end
  end
end
