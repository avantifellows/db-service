defmodule DbserviceWeb.GroupTypeView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupTypeView
  alias DbserviceWeb.GroupView
  alias DbserviceWeb.ProgramView
  alias DbserviceWeb.BatchView
  alias Dbservice.Repo
  alias Dbservice.Groups.Group
  alias Dbservice.Batches.Batch
  alias Dbservice.Programs.Program

  def render("index.json", %{group_type: group_type}) do
    render_many(group_type, GroupTypeView, "group_type.json")
  end

  def render("show.json", %{group_type: group_type}) do
    render_one(group_type, GroupTypeView, "group_type.json")
  end

  def render("group_type.json", %{group_type: group_type}) do
    case group_type.type do
      "group" ->
        group = Repo.get!(Group, group_type.child_id)

        %{
          id: group_type.id,
          type: group_type.type,
          child_id: render_one(group, GroupView, "group.json")
        }

      "program" ->
        program = Repo.get!(Program, group_type.child_id)

        %{
          id: group_type.id,
          type: group_type.type,
          child_id: render_one(program, ProgramView, "program.json")
        }

      "batch" ->
        batch = Repo.get!(Batch, group_type.child_id)

        %{
          id: group_type.id,
          type: group_type.type,
          child_id: render_one(batch, BatchView, "batch.json")
        }

      _ ->
        %{
          id: group_type.id,
          type: group_type.type,
          child_id: group_type.child_id
        }
    end
  end
end
