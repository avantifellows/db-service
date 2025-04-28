defmodule DbserviceWeb.GroupView do
  alias Dbservice.Schools.School
  use DbserviceWeb, :view
  alias Dbservice.Repo
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Batches.Batch
  alias Dbservice.Programs.Program
  alias Dbservice.Grades.Grade
  alias DbserviceWeb.AuthGroupView, as: AuthGroupView
  alias DbserviceWeb.ProgramView, as: ProgramView
  alias DbserviceWeb.BatchView, as: BatchView
  alias DbserviceWeb.SchoolView, as: SchoolView
  alias DbserviceWeb.GradeView, as: GradeView

  def render("index.json", %{group: groups}) do
    Enum.map(groups, &group_json/1)
  end

  def render("show.json", %{group: group}) do
    group_json(group)
  end

  def group_json(%{type: type, child_id: child_id} = group) do
    case group.type do
      "auth-group" ->
        auth_group = Repo.get!(AuthGroup, group.child_id)

        %{
          id: group.id,
          type: type,
          child_id: AuthGroupView.auth_group_json(auth_group)
        }

      "program" ->
        program = Repo.get!(Program, group.child_id)

        %{
          id: group.id,
          type: type,
          child_id: ProgramView.program_json(program)
        }

      "batch" ->
        batch = Repo.get!(Batch, group.child_id)

        %{
          id: group.id,
          type: type,
          child_id: BatchView.batch_json(batch)
        }

      "school" ->
        school = Repo.get!(School, group.child_id)

        %{
          id: group.id,
          type: type,
          child_id: SchoolView.school_json(school)
        }

      "grade" ->
        grade = Repo.get!(Grade, group.child_id)

        %{
          id: group.id,
          type: type,
          child_id: GradeView.grade_json(grade)
        }

      _ ->
        %{
          id: group.id,
          type: type,
          child_id: child_id
        }
    end
  end
end
