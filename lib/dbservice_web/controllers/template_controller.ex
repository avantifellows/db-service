defmodule DbserviceWeb.TemplateController do
  use DbserviceWeb, :controller
  alias Dbservice.DataImport

  @doc """
  Downloads a CSV template for the specified import type.
  """
  def download_csv_template(conn, %{"type" => import_type}) do
    # Validate that the import type is supported
    if import_type in [
         "student",
         "student_update",
         "teacher_addition",
         "batch_movement",
         "teacher_batch_assignment",
         "update_incorrect_batch_id_to_correct_batch_id",
         "update_incorrect_school_to_correct_school",
         "update_incorrect_grade_to_correct_grade",
         "update_incorrect_auth_group_to_correct_auth_group"
       ] do
      csv_content = DataImport.generate_csv_template(import_type)

      filename =
        DataImport.format_type_name(import_type)
        |> String.replace(" ", "")
        |> Kernel.<>(".csv")

      conn
      |> put_resp_content_type("text/csv")
      |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
      |> send_resp(200, csv_content)
    else
      conn
      |> put_status(404)
      |> json(%{error: "Template not found for import type: #{import_type}"})
    end
  end
end
