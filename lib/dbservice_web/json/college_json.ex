defmodule DbserviceWeb.CollegeJSON do
  def index(%{college: colleges}) do
    for c <- colleges, do: render(c)
  end

  def show(%{college: college}) do
    render(college)
  end

  def render(college) do
    %{
      college_id: college.college_id,
      name: college.name,
      state: college.state,
      address: college.address,
      district_code: college.district_code,
      gender_type: college.gender_type,
      college_type: college.college_type,
      management_type: college.management_type,
      year_established: college.year_established,
      affiliated_to: college.affiliated_to,
      tuition_fee: college.tuition_fee,
      af_hierarchy: college.af_hierarchy,
      expected_salary: college.expected_salary,
      salary_tier: college.salary_tier,
      qualifying_exam: college.qualifying_exam,
      nirf_ranking: college.nirf_ranking,
      top_200_nirf: college.top_200_nirf
    }
  end
end
