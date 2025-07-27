defmodule DbserviceWeb.SkillJSON do
  def index(%{skill: skill}) do
    for(s <- skill, do: render(s))
  end

  def show(%{skill: skill}) do
    render(skill)
  end

  defp render(skill) do
    %{
      id: skill.id,
      name: skill.name
    }
  end
end
