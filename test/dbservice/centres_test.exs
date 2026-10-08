defmodule Dbservice.CentresTest do
  use Dbservice.DataCase

  alias Dbservice.Centres
  alias Dbservice.Centres.Centre

  import Dbservice.CentresFixtures
  import Dbservice.ProgramsFixtures
  import Dbservice.SchoolsFixtures

  describe "centre group rows" do
    test "create_centre/1 creates the centre and its group row" do
      assert {:ok, %Centre{} = centre} = Centres.create_centre(%{name: "Bathinda CoE"})

      group = Centres.get_centre_group(centre.id)

      assert group.type == "centre"
      assert group.child_id == centre.id
    end

    test "a centre inserted outside db-service still gets a group row" do
      # AF LMS writes centres straight into Postgres, bypassing this app, so the
      # guarantee has to come from the DB trigger rather than the context.
      %{rows: [[centre_id]]} =
        Repo.query!("INSERT INTO centres (name) VALUES ('Punjab Nodal') RETURNING id")

      group = Centres.get_centre_group(centre_id)

      assert group.type == "centre"
      assert group.child_id == centre_id
    end

    test "a centre cannot have two group rows" do
      centre = centre_fixture()

      assert_raise Ecto.ConstraintError, ~r/group_centre_child_unique/, fn ->
        Repo.insert!(%Dbservice.Groups.Group{type: "centre", child_id: centre.id})
      end
    end

    test "get_centre_group/1 returns nil for a centre that does not exist" do
      refute Centres.get_centre_group(-1)
    end
  end

  describe "get_active_centre_by_school_and_program/2" do
    setup do
      school = school_fixture()
      program = program_fixture()

      %{school: school, program: program}
    end

    test "returns the active centre for the pair", %{school: school, program: program} do
      centre = centre_fixture(%{school_id: school.id, program_id: program.id})

      assert %Centre{} =
               found = Centres.get_active_centre_by_school_and_program(school.id, program.id)

      assert found.id == centre.id
    end

    test "ignores inactive centres", %{school: school, program: program} do
      centre_fixture(%{school_id: school.id, program_id: program.id, is_active: false})

      refute Centres.get_active_centre_by_school_and_program(school.id, program.id)
    end

    test "returns nil when either side is nil", %{school: school} do
      refute Centres.get_active_centre_by_school_and_program(school.id, nil)
      refute Centres.get_active_centre_by_school_and_program(nil, nil)
    end

    test "a second active centre for the same pair is rejected", %{
      school: school,
      program: program
    } do
      centre_fixture(%{school_id: school.id, program_id: program.id})

      assert {:error, changeset} =
               Centres.create_centre(%{
                 name: "duplicate",
                 school_id: school.id,
                 program_id: program.id
               })

      assert "an active centre already exists for this school and program" in errors_on(changeset).school_id
    end
  end

  describe "centre changeset" do
    test "requires a name" do
      assert {:error, changeset} = Centres.create_centre(%{})
      assert "can't be blank" in errors_on(changeset).name
    end
  end
end
