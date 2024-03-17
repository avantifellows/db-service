defmodule DbserviceWeb.GroupUserView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupUserView

  def render("index.json", %{group_user: group_user}) do
    render_many(group_user, GroupUserView, "group_user.json")
  end

  def render("show.json", %{group_user: group_user}) do
    render_one(group_user, GroupUserView, "group_user.json")
  end

  def render("group_user.json", %{group_user: group_user}) do
    %{
      id: group_user.id,
      program_date_of_joining: group_user.program_date_of_joining,
      program_student_language: group_user.program_student_language,
      group_id: group_user.group_id,
      user_id: group_user.user_id,
      program_manager_id: group_user.program_manager_id
    }
  end
end
