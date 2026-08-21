defmodule Dbservice.DataImport.StudentUpdateAuthGroupScopeTest do
  @moduledoc """
  The generic student_update import must resolve a Student ID within its auth
  group — the same Student ID can exist in multiple auth groups, and a global
  match could update the wrong Student (issue #703, building on PR #558).
  apaar_id is globally unique, so it keeps the global lookup.
  """
  use Dbservice.DataCase
  use Oban.Testing, repo: Dbservice.Repo

  alias Dbservice.AuthGroups
  alias Dbservice.DataImport
  alias Dbservice.DataImport.ImportWorker
  alias Dbservice.Users

  import Dbservice.DataImportFixtures

  @dup_id "DUP-ID-703"

  setup do
    on_exit(fn -> cleanup_test_csv("student_update_703.csv") end)
    :ok
  end

  # create_auth_group_from_import also creates the "auth_group" group wrapper that
  # ownership enrollment resolution relies on.
  defp auth_group_fixture(name) do
    {:ok, ag} = AuthGroups.create_auth_group_from_import(%{"name" => name})
    ag
  end

  defp student_in_auth_group(student_id, auth_group_name, first_name, extra \\ %{}) do
    {:ok, student} =
      Users.create_or_update_student(
        Map.merge(
          %{
            "student_id" => student_id,
            "auth_group" => auth_group_name,
            "first_name" => first_name,
            "last_name" => "Student",
            "role" => "student",
            "start_date" => "2025-01-01"
          },
          extra
        )
      )

    student
  end

  defp first_name_of(student) do
    Users.get_user!(student.user_id).first_name
  end

  defp run_student_update(csv_content) do
    filename = create_test_csv("student_update_703.csv", csv_content)

    import_record =
      import_fixture(%{filename: filename, type: "student_update", status: "pending"})

    result = perform_job(ImportWorker, %{"id" => import_record.id})
    {result, DataImport.get_import!(import_record.id)}
  end

  describe "student_update lookup scoped by auth group (issue #703)" do
    test "updates only the Student in the supplied auth group when the ID is duplicated" do
      ag_a = auth_group_fixture("AuthA-703")
      ag_b = auth_group_fixture("AuthB-703")
      student_a = student_in_auth_group(@dup_id, ag_a.name, "AliceOriginal")
      student_b = student_in_auth_group(@dup_id, ag_b.name, "BobOriginal")
      refute student_a.id == student_b.id

      csv = """
      student_id,auth_group,user_first_name
      #{@dup_id},#{ag_a.name},AliceUpdated
      """

      {result, import_record} = run_student_update(csv)

      assert result == :ok
      assert import_record.status in ["completed", "processing"]
      # Only AuthA's student changed; AuthB's is untouched.
      assert first_name_of(student_a) == "AliceUpdated"
      assert first_name_of(student_b) == "BobOriginal"
    end

    test "fails clearly when a Student ID update supplies no auth group" do
      ag_a = auth_group_fixture("AuthA-703b")
      ag_b = auth_group_fixture("AuthB-703b")
      student_a = student_in_auth_group(@dup_id, ag_a.name, "AliceOriginal")
      student_b = student_in_auth_group(@dup_id, ag_b.name, "BobOriginal")

      csv = """
      student_id,user_first_name
      #{@dup_id},ShouldNotApply
      """

      {_result, import_record} = run_student_update(csv)

      assert import_record.status == "failed"
      assert [%{"error" => error} | _] = import_record.error_details
      assert error =~ "auth_group is required"
      # Neither Student was touched.
      assert first_name_of(student_a) == "AliceOriginal"
      assert first_name_of(student_b) == "BobOriginal"
    end

    test "fails clearly when the supplied auth group does not exist" do
      ag_a = auth_group_fixture("AuthA-703c")
      student_a = student_in_auth_group(@dup_id, ag_a.name, "AliceOriginal")

      csv = """
      student_id,auth_group,user_first_name
      #{@dup_id},NoSuchAuthGroup,ShouldNotApply
      """

      {_result, import_record} = run_student_update(csv)

      assert import_record.status == "failed"
      assert [%{"error" => error} | _] = import_record.error_details
      assert error =~ "was not found"
      assert first_name_of(student_a) == "AliceOriginal"
    end

    test "errors when the Student ID is not in the supplied auth group" do
      ag_a = auth_group_fixture("AuthA-703d")
      ag_b = auth_group_fixture("AuthB-703d")
      # Student exists only in AuthA; the update targets AuthB.
      student_a = student_in_auth_group(@dup_id, ag_a.name, "AliceOriginal")

      csv = """
      student_id,auth_group,user_first_name
      #{@dup_id},#{ag_b.name},ShouldNotApply
      """

      {_result, import_record} = run_student_update(csv)

      assert import_record.status == "failed"
      assert [%{"error" => error} | _] = import_record.error_details
      assert error =~ "not found for student_id"
      assert first_name_of(student_a) == "AliceOriginal"
    end

    test "still updates globally by apaar_id (globally unique) without an auth group" do
      ag_a = auth_group_fixture("AuthA-703e")

      student =
        student_in_auth_group(@dup_id, ag_a.name, "AliceOriginal", %{
          "apaar_id" => "703000000012"
        })

      csv = """
      student_apaar_id,user_first_name
      703000000012,AliceViaApaar
      """

      {result, import_record} = run_student_update(csv)

      assert result == :ok
      assert import_record.status in ["completed", "processing"]
      assert first_name_of(student) == "AliceViaApaar"
    end
  end
end
