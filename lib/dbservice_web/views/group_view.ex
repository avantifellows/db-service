defmodule DbserviceWeb.GroupView do
  alias DbserviceWeb.GradeView
  alias DbserviceWeb.SchoolView
  alias Dbservice.Schools.School
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupView
  alias DbserviceWeb.AuthGroupView
  alias DbserviceWeb.ProgramView
  alias DbserviceWeb.BatchView
  alias DbserviceWeb.GradeView
  alias Dbservice.Repo
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Batches.Batch
  alias Dbservice.Programs.Program
  alias Dbservice.Grades.Grade

  def render("index.json", %{group: group}) do
    render_many(group, GroupView, "group.json")
  end

  def render("show.json", %{group: group}) do
    render_one(group, GroupView, "group.json")
  end

  def render("group.json", %{group: group}) do
    case group.type do
      "auth-group" ->
        auth_group = Repo.get!(AuthGroup, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: render_one(auth_group, AuthGroupView, "auth_group.json")
        }

      "program" ->
        program = Repo.get!(Program, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: render_one(program, ProgramView, "program.json")
        }

      "batch" ->
        batch = Repo.get!(Batch, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: render_one(batch, BatchView, "batch.json")
        }

      "school" ->
        school = Repo.get!(School, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: render_one(school, SchoolView, "school.json")
        }

      "grade" ->
        grade = Repo.get!(Grade, group.child_id)

        %{
          id: group.id,
          type: group.type,
          child_id: render_one(grade, GradeView, "grade.json")
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
