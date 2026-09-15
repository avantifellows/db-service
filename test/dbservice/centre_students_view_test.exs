defmodule Dbservice.CentreStudentsViewTest do
  @moduledoc """
  Behavioural coverage for the `centre_students` view: membership is
  "in the centre's school AND holds any batch in the centre's program".
  Regression for the 2026-09-10 case where a student in two non-JNV
  program batches (Punjab Test Series + Punjab CoE) vanished from the
  Punjab CoE centre because the old view attributed them to a single
  program via a JNV-name tiebreak.
  """
  use Dbservice.DataCase, async: false

  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Grades.Grade
  alias Dbservice.Groups.Group
  alias Dbservice.Groups.GroupUser
  alias Dbservice.Programs.Program
  alias Dbservice.Repo
  alias Dbservice.Schools.School
  alias Dbservice.UsersFixtures

  setup do
    Ecto.Adapters.SQL.query!(Repo, "DELETE FROM centres")
    :ok
  end

  test "a student in two non-JNV program batches is in the centre whose program they hold" do
    school = insert_school!("RSMS Test")
    grade = insert_grade!(11)
    test_series = insert_program!("STP Test Series Test")
    coe = insert_program!("Test CoE")
    centre_id = insert_active_centre!(school, coe.id)

    student = enrol_student!(school, grade, [test_series, coe])

    assert members(centre_id) == [student.id]
  end

  test "a student in the school without a batch in the centre's program is not a member" do
    school = insert_school!("RSMS Test")
    grade = insert_grade!(11)
    test_series = insert_program!("STP Test Series Test")
    coe = insert_program!("Test CoE")
    centre_id = insert_active_centre!(school, coe.id)

    _outsider = enrol_student!(school, grade, [test_series])

    assert members(centre_id) == []
  end

  test "two centres at one school each get the students holding their own program" do
    school = insert_school!("RSMS Test")
    grade = insert_grade!(11)
    coe = insert_program!("Test CoE")
    nodal = insert_program!("Test Nodal")
    coe_centre = insert_active_centre!(school, coe.id)
    nodal_centre = insert_active_centre!(school, nodal.id)

    coe_student = enrol_student!(school, grade, [coe])
    nodal_student = enrol_student!(school, grade, [nodal])

    assert members(coe_centre) == [coe_student.id]
    assert members(nodal_centre) == [nodal_student.id]
  end

  test "an inactive centre has no members" do
    school = insert_school!("RSMS Test")
    grade = insert_grade!(11)
    coe = insert_program!("Test CoE")
    centre_id = insert_active_centre!(school, coe.id)
    _student = enrol_student!(school, grade, [coe])

    Ecto.Adapters.SQL.query!(Repo, "UPDATE centres SET is_active = false WHERE id = $1", [
      centre_id
    ])

    assert members(centre_id) == []
  end

  test "exposes the centre's program_id and the student's current grade" do
    school = insert_school!("RSMS Test")
    grade = insert_grade!(11)
    coe = insert_program!("Test CoE")
    centre_id = insert_active_centre!(school, coe.id)
    student = enrol_student!(school, grade, [coe])

    %{rows: [[^centre_id, user_id, "2026-2027", 11, program_id]]} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT centre_id, user_id, academic_year, grade, program_id FROM centre_students WHERE centre_id = $1",
        [centre_id]
      )

    assert user_id == student.id
    assert program_id == coe.id
  end

  defp members(centre_id) do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT user_id FROM centre_students WHERE centre_id = $1 ORDER BY user_id",
        [centre_id]
      )

    List.flatten(rows)
  end

  defp enrol_student!(school, grade, programs) do
    user = UsersFixtures.user_fixture()
    ensure_group_user!(user.id, "school", school.id)
    ensure_group_user!(user.id, "grade", grade.id)
    insert_enrollment!(user.id, grade.id, "grade")

    for program <- programs do
      batch = insert_batch!(program)
      ensure_group_user!(user.id, "batch", batch.id)
      insert_enrollment!(user.id, batch.id, "batch")
    end

    user
  end

  defp insert_school!(name) do
    school =
      Repo.insert!(%School{
        code: "T-#{System.unique_integer([:positive])}",
        name: name,
        udise_code: "#{System.unique_integer([:positive])}",
        af_school_category: "RSMS",
        district_code: "D001",
        district: "Test",
        state_code: "PB",
        state: "Punjab",
        program_ids: []
      })

    ensure_group!("school", school.id)
    school
  end

  defp insert_grade!(number) do
    grade = Repo.get_by(Grade, number: number) || Repo.insert!(%Grade{number: number})
    ensure_group!("grade", grade.id)
    grade
  end

  defp insert_program!(name) do
    product =
      Dbservice.ProductsFixtures.product_fixture(%{
        code: "P-#{System.unique_integer([:positive])}"
      })

    Repo.insert!(%Program{
      name: name,
      product_id: product.id,
      target_outreach: 100,
      donor: "Test",
      state: "Punjab",
      model: "Test",
      is_current: true
    })
  end

  defp insert_batch!(program) do
    {:ok, batch} =
      Dbservice.Batches.create_batch(%{
        name: "#{program.name} batch",
        batch_id: "B-#{System.unique_integer([:positive])}",
        program_id: program.id,
        start_date: ~D[2026-06-01],
        end_date: ~D[2027-03-31],
        contact_hours_per_week: 10,
        af_medium: "offline",
        system: "test"
      })

    ensure_group!("batch", batch.id)
    batch
  end

  defp insert_active_centre!(school, program_id) do
    %{rows: [[id]]} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "INSERT INTO centres (name, school_id, program_id, is_active) VALUES ($1, $2, $3, true) RETURNING id",
        ["#{school.name} Centre #{program_id}", school.id, program_id]
      )

    id
  end

  defp insert_enrollment!(user_id, group_id, group_type) do
    Repo.insert!(%EnrollmentRecord{
      user_id: user_id,
      group_id: group_id,
      group_type: group_type,
      academic_year: "2026-2027",
      start_date: ~D[2026-06-01],
      is_current: true
    })
  end

  defp ensure_group_user!(user_id, type, child_id) do
    group = ensure_group!(type, child_id)
    Repo.insert!(%GroupUser{user_id: user_id, group_id: group.id})
  end

  defp ensure_group!(type, child_id) do
    Repo.get_by(Group, type: type, child_id: child_id) ||
      Repo.insert!(%Group{type: type, child_id: child_id})
  end
end
