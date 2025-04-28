defmodule DbserviceWeb.SchoolView do
  use DbserviceWeb, :view
  alias DbserviceWeb.UserView
  alias Dbservice.Repo

  def render("index.json", %{school: school}) do
    Enum.map(school, &school_json/1)
  end

  def render("show.json", %{school: school}) do
    school_json(school)
  end

  def school_json(%{__meta__: _} = school) do
    school = Repo.preload(school, :user)

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
      # board_medium: school.board_medium,
      user_id: school.user_id,
      user: UserView.user_json(school.user)
    }
  end
end
