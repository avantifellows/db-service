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
      district: college.district,
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
      top_200_nirf: college.top_200_nirf,
      placement_rate: college.placement_rate,
      median_salary: college.median_salary,
      entrance_test: college.entrance_test,
      tuition_fees_annual: college.tuition_fees_annual
    }
  end
end
