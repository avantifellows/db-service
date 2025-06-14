defmodule DbserviceWeb.SchoolJSON do
  alias DbserviceWeb.UserJSON

  def index(%{school: school}) do
    %{data: for(s <- school, do: data(s))}
  end

  def show(%{school: school}) do
    %{data: data(school)}
  end

  def data(school) do
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
      user: if(school.user, do: UserJSON.data(school.user), else: nil)
    }
  end
end
