defmodule DbserviceWeb.SchoolJSON do
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
      user: if(school.user, do: UserJSON.render(school.user), else: nil)
    }
  end
end
