defmodule DbserviceWeb.CollegeView do
  @moduledoc """
  Handles JSON rendering for College resources.
  """
  use DbserviceWeb, :view

  @doc """
  Renders a paginated list of colleges.
  """
  def render("index.json", %{page: %{entries: colleges, page_number: page_number, page_size: page_size, total_entries: total_entries, total_pages: total_pages}}) do
    %{
      data: Enum.map(colleges, &college_json/1),
      meta: %{
        page_number: page_number,
        page_size: page_size,
        total_entries: total_entries,
        total_pages: total_pages
      }
    }
  end

  @doc """
  Renders a single college.
  """
  def render("show.json", %{college: college}) do
    %{data: college_json(college)}
  end

  # Private helper functions

  defp college_json(%Dbservice.Colleges.College{} = college) do
    %{
      id: college.id,
      college_id: college.college_id,
      institute: college.institute,
      state: college.state,
      place: college.place,
      dist_code: college.dist_code,
      co_ed: college.co_ed,
      college_type: college.college_type,
      year_established: college.year_established,
      affiliated_to: college.affiliated_to,
      tuition_fee: college.tuition_fee,
      af_hierarchy: college.af_hierarchy,
      college_ranking: college.college_ranking,
      management_type: college.management_type,
      expected_salary: college.expected_salary,
      salary_tier: college.salary_tier,
      qualifying_exam: college.qualifying_exam,
      top_200_nirf: college.top_200_nirf,
      inserted_at: college.inserted_at,
      updated_at: college.updated_at
    }
  end
end
