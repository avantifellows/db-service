defmodule Dbservice.ProblemLanguagesTest do
  use Dbservice.DataCase

  alias Dbservice.ProblemLanguages
  alias Dbservice.Resources

  # Unique codes to avoid colliding with any pre-existing language in the test DB.
  defp language_fixture(code, name) do
    {:ok, language} = Dbservice.Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  describe "list_lang_versions_by_resource_id/1" do
    test "returns one entry per language version with lang_code and meta_data" do
      en = language_fixture("zle", "LangVersions EN")
      hi = language_fixture("zlh", "LangVersions HI")
      problem = problem_fixture()

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem.id,
          lang_id: en.id,
          meta_data: %{"text" => "What is 2+2?"}
        })

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem.id,
          lang_id: hi.id,
          meta_data: %{"text" => "2+2 क्या है?"}
        })

      assert [
               %{lang_code: "zle", meta_data: %{"text" => "What is 2+2?"}},
               %{lang_code: "zlh", meta_data: %{"text" => "2+2 क्या है?"}}
             ] = ProblemLanguages.list_lang_versions_by_resource_id(problem.id)
    end

    test "returns an empty list when the problem has no language versions" do
      problem = problem_fixture()

      assert ProblemLanguages.list_lang_versions_by_resource_id(problem.id) == []
    end

    test "does not include language versions of other problems" do
      en = language_fixture("zlx", "LangVersions Other")
      problem = problem_fixture()
      other_problem = problem_fixture()

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: other_problem.id,
          lang_id: en.id,
          meta_data: %{"text" => "other"}
        })

      assert ProblemLanguages.list_lang_versions_by_resource_id(problem.id) == []
    end
  end

  describe "list_lang_versions_by_resource_ids/1" do
    test "returns an empty map for an empty list of ids" do
      assert ProblemLanguages.list_lang_versions_by_resource_ids([]) == %{}
    end

    test "groups lang_versions by resource id in a single lookup" do
      en = language_fixture("zbe", "Batch EN")
      hi = language_fixture("zbh", "Batch HI")
      problem_one = problem_fixture()
      problem_two = problem_fixture()

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem_one.id,
          lang_id: en.id,
          meta_data: %{"text" => "one-en"}
        })

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem_one.id,
          lang_id: hi.id,
          meta_data: %{"text" => "one-hi"}
        })

      {:ok, _} =
        ProblemLanguages.create_problem_language(%{
          res_id: problem_two.id,
          lang_id: en.id,
          meta_data: %{"text" => "two-en"}
        })

      result =
        ProblemLanguages.list_lang_versions_by_resource_ids([problem_one.id, problem_two.id])

      assert result[problem_one.id] == [
               %{lang_code: "zbe", meta_data: %{"text" => "one-en"}},
               %{lang_code: "zbh", meta_data: %{"text" => "one-hi"}}
             ]

      assert result[problem_two.id] == [
               %{lang_code: "zbe", meta_data: %{"text" => "two-en"}}
             ]
    end

    test "omits ids that have no language versions" do
      problem = problem_fixture()

      assert ProblemLanguages.list_lang_versions_by_resource_ids([problem.id]) == %{}
    end
  end
end
