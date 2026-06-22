defmodule Dbservice.ResourcesTest do
  use Dbservice.DataCase

  alias Dbservice.Resources
  alias Dbservice.ResourceCurriculums

  import Dbservice.GradesFixtures

  describe "create_resource_curriculums_for_resource/2 grade requirement" do
    defp curriculum_fixture do
      {:ok, curriculum} =
        Dbservice.Curriculums.create_curriculum(%{"name" => "CLAT", "code" => "CLAT"})

      curriculum
    end

    defp resource_fixture(type) do
      {:ok, resource} =
        Resources.create_resource(%{"type" => type, "type_params" => %{}})

      resource
    end

    test "creates a curriculum entry for a non-problem/test resource without a grade_id" do
      resource = resource_fixture("video")
      curriculum = curriculum_fixture()

      params = %{
        "curriculum_grades" => [%{"curriculum_id" => curriculum.id}],
        "subject_id" => nil
      }

      assert :ok = Resources.create_resource_curriculums_for_resource(resource, params)

      [rc] = ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)
      assert rc.curriculum_id == curriculum.id
      assert is_nil(rc.grade_id)
    end

    test "creates a curriculum entry for a non-problem/test resource with a grade_id" do
      resource = resource_fixture("video")
      curriculum = curriculum_fixture()
      grade = grade_fixture()

      params = %{
        "curriculum_grades" => [%{"curriculum_id" => curriculum.id, "grade_id" => grade.id}]
      }

      assert :ok = Resources.create_resource_curriculums_for_resource(resource, params)

      [rc] = ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)
      assert rc.grade_id == grade.id
    end

    test "rejects a problem resource whose curriculum entry has no grade_id" do
      resource = resource_fixture("problem")
      curriculum = curriculum_fixture()

      params = %{"curriculum_grades" => [%{"curriculum_id" => curriculum.id}]}

      assert {:error, message} =
               Resources.create_resource_curriculums_for_resource(resource, params)

      assert message =~ "grade_id is required"
      assert ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id) == []
    end

    test "rejects a test resource whose curriculum entry has no grade_id" do
      resource = resource_fixture("test")
      curriculum = curriculum_fixture()

      params = %{"curriculum_grades" => [%{"curriculum_id" => curriculum.id}]}

      assert {:error, message} =
               Resources.create_resource_curriculums_for_resource(resource, params)

      assert message =~ "grade_id is required"
    end

    test "allows a problem resource when grade_id is present" do
      resource = resource_fixture("problem")
      curriculum = curriculum_fixture()
      grade = grade_fixture()

      params = %{
        "curriculum_grades" => [%{"curriculum_id" => curriculum.id, "grade_id" => grade.id}]
      }

      assert :ok = Resources.create_resource_curriculums_for_resource(resource, params)

      [rc] = ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)
      assert rc.grade_id == grade.id
    end
  end
end
