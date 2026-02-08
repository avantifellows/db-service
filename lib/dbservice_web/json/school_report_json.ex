defmodule DbserviceWeb.SchoolReportJSON do
  @moduledoc """
  JSON rendering for school reports
  """

  def index(%{reports: reports, school: school}) do
    %{
      data: for(report <- reports, do: render_report(report)),
      school: render_school(school)
    }
  end

  def show(%{url: url, test_name: test_name}) do
    %{
      url: url,
      test_name: test_name
    }
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp render_report(report) do
    %{
      test_name: report.test_name,
      file_name: report.file_name
    }
  end

  defp render_school(school) do
    %{
      name: school.name,
      code: school.code
    }
  end
end
