defmodule DbserviceWeb.ResourceProblemTestsTest do
  @moduledoc """
  GET /api/resource/problem/:problem_id must always carry a `tests` array naming
  the tests the problem appears in (issue #768). The CMS single-problem screen
  bypasses its cache for this fetch and hides the section when the key is
  missing, so `[]` must be returned rather than nothing.
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Curriculums
  alias Dbservice.Languages
  alias Dbservice.ProblemLanguages
  alias Dbservice.ResourceCurriculums
  alias Dbservice.Resources

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  defp curriculum_fixture do
    {:ok, curriculum} =
      Curriculums.create_curriculum(%{"name" => "Problem Tests", "code" => "PTCURR"})

    curriculum
  end

  defp resource_curriculum_fixture(resource, curriculum) do
    {:ok, rc} =
      ResourceCurriculums.create_resource_curriculum(%{
        resource_id: resource.id,
        curriculum_id: curriculum.id,
        difficulty_level: "medium"
      })

    rc
  end

  # A test points at its problems through type_params, not a join table, so the
  # fixtures below mirror the nesting the extractor walks.
  defp test_fixture(code, problem_ids, opts \\ []) do
    slot = Keyword.get(opts, :slot, "compulsory")
    problems = Enum.map(problem_ids, &%{"id" => &1, "pos_marks" => [1], "neg_marks" => [-1]})

    subjects = [
      %{"subject_id" => 1, "sections" => [%{"name" => "s1", slot => %{"problems" => problems}}]}
    ]

    type_params =
      if Keyword.get(opts, :nested, false) do
        %{"type_params" => %{"subjects" => subjects}}
      else
        %{"subjects" => subjects}
      end

    {:ok, test} =
      Resources.create_resource(%{
        "type" => "test",
        "code" => code,
        "type_params" => type_params
      })

    test
  end

  defp get_problem(conn, path) do
    conn |> get(path) |> json_response(200)
  end

  describe "GET /api/resource/problem/:problem_id tests array" do
    test "lists the tests the problem appears in", %{conn: conn} do
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)
      test_a = test_fixture("PT-TEST-A", [problem.id])

      body = get_problem(conn, ~p"/api/resource/problem/#{problem.id}")

      assert body["tests"] == [%{"test_id" => test_a.id, "test_code" => "PT-TEST-A"}]
    end

    test "is an empty array when the problem is in no test", %{conn: conn} do
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      body = get_problem(conn, ~p"/api/resource/problem/#{problem.id}")

      assert Map.has_key?(body, "tests")
      assert body["tests"] == []
    end

    test "returns every test, ordered by test id", %{conn: conn} do
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)
      first = test_fixture("PT-TEST-1", [problem.id])
      second = test_fixture("PT-TEST-2", [problem.id])

      body = get_problem(conn, ~p"/api/resource/problem/#{problem.id}")

      assert body["tests"] == [
               %{"test_id" => first.id, "test_code" => "PT-TEST-1"},
               %{"test_id" => second.id, "test_code" => "PT-TEST-2"}
             ]
    end

    test "ignores tests that contain only other problems", %{conn: conn} do
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      other = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)
      mine = test_fixture("PT-TEST-MINE", [problem.id])
      test_fixture("PT-TEST-OTHER", [other.id])

      body = get_problem(conn, ~p"/api/resource/problem/#{problem.id}")

      assert body["tests"] == [%{"test_id" => mine.id, "test_code" => "PT-TEST-MINE"}]
    end

    test "finds the problem in an optional section and under nested type_params",
         %{conn: conn} do
      curriculum = curriculum_fixture()
      optional_problem = problem_fixture()
      nested_problem = problem_fixture()
      resource_curriculum_fixture(optional_problem, curriculum)
      resource_curriculum_fixture(nested_problem, curriculum)

      optional_test = test_fixture("PT-TEST-OPT", [optional_problem.id], slot: "optional")
      nested_test = test_fixture("PT-TEST-NEST", [nested_problem.id], nested: true)

      optional_body = get_problem(conn, ~p"/api/resource/problem/#{optional_problem.id}")
      nested_body = get_problem(conn, ~p"/api/resource/problem/#{nested_problem.id}")

      assert optional_body["tests"] ==
               [%{"test_id" => optional_test.id, "test_code" => "PT-TEST-OPT"}]

      assert nested_body["tests"] ==
               [%{"test_id" => nested_test.id, "test_code" => "PT-TEST-NEST"}]
    end

    test "is present on the curriculum_id and lang_code variants too", %{conn: conn} do
      {:ok, language} = Languages.create_language(%{"name" => "PT EN", "code" => "pte"})
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem.id,
          lang_id: language.id,
          meta_data: %{"text" => "q"}
        })

      expected = [
        %{"test_id" => test_fixture("PT-TEST-V", [problem.id]).id, "test_code" => "PT-TEST-V"}
      ]

      with_curriculum =
        get_problem(conn, ~p"/api/resource/problem/#{problem.id}/#{curriculum.id}")

      with_lang =
        get_problem(conn, ~p"/api/resource/problem/#{problem.id}/pte/#{curriculum.id}")

      assert with_curriculum["tests"] == expected
      assert with_lang["tests"] == expected
    end
  end
end
