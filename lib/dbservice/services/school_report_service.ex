defmodule Dbservice.Services.SchoolReportService do
  alias Dbservice.Schools

  @moduledoc """
  Service for fetching school reports from S3
  """

  @s3_bucket Application.compile_env(:dbservice, :s3_bucket)
  @report_base_path "reports/nvs_test_reports"

  @doc """
  Get available reports for a school by school code (or UDISE code)
  Returns a list of test reports with metadata
  """
  def list_reports_by_school_code(school_code) do
    case Schools.get_school_by_code(school_code) do
      nil -> {:error, :school_not_found}
      school -> list_reports_by_udise(school.udise_code, school)
    end
  end

  defp list_reports_by_udise(udise_code, school) do
    path = "#{@report_base_path}/"

    case ExAws.S3.list_objects(@s3_bucket, prefix: path, delimiter: "/") |> ExAws.request() do
      {:ok, %{body: %{common_prefixes: prefixes}}} ->
        reports =
          prefixes
          |> Enum.map(fn %{prefix: prefix} ->
            String.replace(prefix, path, "") |> String.replace("/", "")
          end)
          |> Enum.filter(fn test_name -> report_exists?(test_name, udise_code) end)
          |> Enum.map(fn test_name ->
            %{
              test_name: test_name,
              school_code: school.code,
              school_name: school.name,
              udise_code: udise_code,
              file_name: "#{udise_code}.pdf"
            }
          end)

        {:ok, reports}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def report_exists?(test_name, udise_code) do
    path = build_report_path(test_name, udise_code)

    case ExAws.S3.head_object(@s3_bucket, path) |> ExAws.request() do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Get presigned URL for viewing report
  """
  def get_report_url(school_code, test_name, opts \\ []) do
    case Schools.get_school_by_code(school_code) do
      nil ->
        {:error, :school_not_found}

      school ->
        expires_in = Keyword.get(opts, :expires_in, 3600)
        path = build_report_path(test_name, school.udise_code)

        if report_exists?(test_name, school.udise_code) do
          config = ExAws.Config.new(:s3)

          case ExAws.S3.presigned_url(config, :get, @s3_bucket, path, expires_in: expires_in) do
            {:ok, url} -> {:ok, url}
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, :report_not_found}
        end
    end
  end

  defp build_report_path(test_name, udise_code) do
    "#{@report_base_path}/#{test_name}/#{udise_code}.pdf"
  end
end
