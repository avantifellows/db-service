defmodule DbserviceWeb.SchoolJSON do
  alias Dbservice.Schools.School
  alias DbserviceWeb.UserJSON

  def index(%{school: school}) do
    for(s <- school, do: render(s))
  end

  def show(%{school: school}) do
    render(school)
  end

  def render(school) do
    school = Dbservice.Repo.preload(school, :user)

    %{
      id: school.id,
      code: school.code,
      name: school.name,
      udise_code: school.udise_code,
      gender_type: school.gender_type,
      af_school_category: school.af_school_category,
      region: school.region,
      state_code: school.state_code,
      state: school.state,
      district_code: school.district_code,
      district: school.district,
      block_code: school.block_code,
      block_name: school.block_name,
      board: school.board,
      user_id: school.user_id,
      program_ids: school.program_ids,
      school_email: school.school_email,
      principal_incharge_name: school.principal_incharge_name,
      principal_incharge_contact: school.principal_incharge_contact,
      pmu_coordinator_name: school.pmu_coordinator_name,
      pmu_coordinator_contact: school.pmu_coordinator_contact,
      school_support_status: school.school_support_status,
      school_residential_status: school.school_residential_status,
      grades_offered: school.grades_offered,
      school_notes: school.school_notes,
      user: if(school.user, do: UserJSON.render(school.user), else: nil)
    }
    |> Map.merge(estimated_strength(school))
  end

  defp estimated_strength(school) do
    Map.new(School.estimated_strength_fields(), &{&1, Map.fetch!(school, &1)})
  end
end
