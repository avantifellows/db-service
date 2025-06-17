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
    for(g <- group, do: data(g))
  end

  def show(%{group: group}) do
    data(group)
  end

  def data(group) do
    case group.type do
      "auth-group" ->
        auth_group = Repo.get!(AuthGroup, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: AuthGroupJSON.data(auth_group)
        }

      "program" ->
        program = Repo.get!(Program, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: ProgramJSON.data(program)
        }

      "batch" ->
        batch = Repo.get!(Batch, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: BatchJSON.data(batch)
        }

      "school" ->
        school = Repo.get!(School, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: SchoolJSON.data(school)
        }

      "grade" ->
        grade = Repo.get!(Grade, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: GradeJSON.data(grade)
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
