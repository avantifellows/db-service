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
end
