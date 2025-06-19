defmodule DbserviceWeb.GroupJSON do
  alias DbserviceWeb.AuthGroupJSON
  alias DbserviceWeb.ProgramJSON
  alias DbserviceWeb.BatchJSON
  alias DbserviceWeb.SchoolJSON
  alias DbserviceWeb.GradeJSON
  alias Dbservice.Repo
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Batches.Batch
  alias Dbservice.Programs.Program
  alias Dbservice.Schools.School
  alias Dbservice.Grades.Grade

  def index(%{group: group}) do
    for(g <- group, do: render(g))
  end

  def show(%{group: group}) do
    render(group)
  end

  def render(group) do
    case group.type do
      "auth-group" ->
        auth_group = Repo.get!(AuthGroup, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: AuthGroupJSON.render(auth_group)
        }

      "program" ->
        program = Repo.get!(Program, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: ProgramJSON.render(program)
        }

      "batch" ->
        batch = Repo.get!(Batch, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: BatchJSON.render(batch)
        }

      "school" ->
        school = Repo.get!(School, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: SchoolJSON.render(school)
        }

      "grade" ->
        grade = Repo.get!(Grade, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: GradeJSON.render(grade)
        }

      _ ->
        %{
          id: group.id,
          type: group.type,
          child_id: group.child_id
        }
    end
  end
end
