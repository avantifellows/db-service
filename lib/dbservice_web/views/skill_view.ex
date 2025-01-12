defmodule DbserviceWeb.SkillView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SkillView

  def render("index.json", %{skill: skill}) do
    render_many(skill, SkillView, "skill.json")
  end

  def render("show.json", %{skill: skill}) do
    render_one(skill, SkillView, "skill.json")
  end

  def render("skill.json", %{skill: skill}) do
    %{
      id: skill.id,
      name: skill.name
    }
  end
end
