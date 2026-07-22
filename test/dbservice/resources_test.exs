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

  describe "get_problems_by_test_and_language/3 ordering" do
    test "returns problems in the order defined in the test's type_params, not by id" do
      # Unique code to avoid colliding with any pre-existing language in the test DB.
      {:ok, _language} =
        Dbservice.Languages.create_language(%{"name" => "Ordering Test", "code" => "zzt"})

      # Created in ascending-id order; the test will define a different order.
      p1 = resource_fixture("problem")
      p2 = resource_fixture("problem")
      p3 = resource_fixture("problem")
      p4 = resource_fixture("problem")

      # Deliberately scrambled relative to id order (mirrors issue #565).
      ordered_ids = [p3.id, p1.id, p4.id, p2.id]

      type_params = %{
        "subjects" => [
          %{
            "subject_id" => 2,
            "sections" => [
              %{
                "type" => "mcq_single_answer",
                "compulsory" => %{
                  "problems" => Enum.map(ordered_ids, fn id -> %{"id" => id} end)
                }
              }
            ]
          }
        ]
      }

      {:ok, test_resource} =
        Resources.create_resource(%{"type" => "test", "type_params" => type_params})

      result = Resources.get_problems_by_test_and_language(test_resource.id, "zzt", 1)

      assert Enum.map(result, & &1.resource.id) == ordered_ids
    end
  end

  describe "list_resources/1 and search_problems/1 pagination limits" do
    setup do
      # Shrink the guardrails so a handful of rows is enough to observe the cap.
      original = Application.get_env(:dbservice, Dbservice.Utils.Pagination)

      Application.put_env(:dbservice, Dbservice.Utils.Pagination,
        default_limit: 2,
        max_limit: 3
      )

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:dbservice, Dbservice.Utils.Pagination)
          env -> Application.put_env(:dbservice, Dbservice.Utils.Pagination, env)
        end
      end)

      :ok
    end

    test "list_resources caps the row count regardless of the requested limit" do
      for _ <- 1..5, do: resource_fixture("video")

      # An over-max limit (e.g. ?limit=100000) is clamped to max_limit, not honored verbatim.
      assert length(Resources.list_resources(%{"limit" => "100000"})) == 3

      # With no limit given, the default limit applies.
      assert length(Resources.list_resources(%{})) == 2
    end

    test "search_problems caps the row count regardless of the requested limit" do
      {:ok, language} =
        Dbservice.Languages.create_language(%{"name" => "Cap Test", "code" => "zct"})

      for _ <- 1..5 do
        resource = resource_fixture("problem")

        {:ok, _problem_lang} =
          Dbservice.ProblemLanguages.create_problem_language(%{
            "res_id" => resource.id,
            "lang_id" => language.id,
            "meta_data" => %{}
          })
      end

      # The problem search runs extra per-row queries, so the cap matters most here.
      assert length(Resources.search_problems(%{"limit" => "100000"})) == 3
      assert length(Resources.search_problems(%{})) == 2
    end
  end
end
