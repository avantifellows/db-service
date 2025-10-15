defmodule DbserviceWeb.SchoolReportController do
  use DbserviceWeb, :controller

  alias Dbservice.Services.SchoolReportService
  alias Dbservice.Repo
  alias Dbservice.Schools.School

  action_fallback DbserviceWeb.FallbackController

  @doc """
  GET /api/reports?school_code=SCHOOL123
  """
  def index(conn, params) do
    school_code = params["school_code"]

    with {:school_code, code} when not is_nil(code) <- {:school_code, school_code},
         {:school, %School{} = school} <- {:school, Repo.get_by(School, code: code)},
         {:reports, {:ok, reports}} <-
           {:reports, SchoolReportService.list_reports_by_school(school)} do
      render(conn, :index, reports: reports, school: school)
    else
      {:school_code, nil} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, message: "School code is required")

      {:school, nil} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "School not found")

      {:reports, {:error, reason}} ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, message: to_string(reason))
    end
  end

  @doc """
  GET /api/reports/:test_name?school_code=SCHOOL123
  Returns presigned URL to view the PDF
  """
  def show(conn, %{"test_name" => test_name} = params) do
    school_code = params["school_code"] || get_req_header(conn, "x-school-code") |> List.first()

    with {:school_code, code} when not is_nil(code) <- {:school_code, school_code},
         {:school, %School{} = school} <- {:school, Repo.get_by(School, code: code)},
         {:url, {:ok, url}} <-
           {:url, SchoolReportService.get_report_url_for_school(school, test_name)} do
      render(conn, :show, url: url, test_name: test_name, expires_in: 3600)
    else
      {:school_code, nil} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, message: "School code is required")

      {:school, nil} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "School not found")

      {:url, {:error, :report_not_found}} ->
        conn
        |> put_status(:not_found)
        |> render(:error, message: "Report not found")

      {:url, {:error, reason}} ->
        conn
        |> put_status(:internal_server_error)
        |> render(:error, message: to_string(reason))
    end
  end
end
