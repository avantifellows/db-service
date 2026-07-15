defmodule DbserviceWeb.ResourceJSONTest do
  use Dbservice.DataCase

  alias Dbservice.ProblemLanguages
  alias Dbservice.Resources
  alias DbserviceWeb.ResourceJSON

  defp language_fixture(code, name) do
    {:ok, language} = Dbservice.Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  defp problem_language_fixture(resource, language, meta_data) do
    {:ok, problem_lang} =
      ProblemLanguages.create_problem_language(%{
        res_id: resource.id,
        lang_id: language.id,
        meta_data: meta_data
      })

    problem_lang
  end

  describe "problems/1" do
    test "renders top-level meta_data for the requested language plus all lang_versions" do
      en = language_fixture("zje", "JSON EN")
      hi = language_fixture("zjh", "JSON HI")
      problem = problem_fixture()

      en_meta = %{"text" => "What is 2+2?"}
      hi_meta = %{"text" => "2+2 क्या है?"}
      en_problem_lang = problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      [rendered] =
        ResourceJSON.problems(%{
          problems: [
            %{
              resource: problem,
              resource_topic: %{},
              resource_curriculums: [],
              requested_curriculum_id: nil,
              problem_lang: en_problem_lang
            }
          ]
        })

      # Old shape stays intact for the currently deployed frontend
      assert rendered.meta_data == en_meta

      # New shape carries every available language
      assert rendered.lang_versions == [
               %{lang_code: "zje", meta_data: en_meta},
               %{lang_code: "zjh", meta_data: hi_meta}
             ]
    end
  end

  describe "problem_lang/1" do
    test "renders top-level meta_data for the requested language plus all lang_versions" do
      en = language_fixture("zke", "JSON Lang EN")
      hi = language_fixture("zkh", "JSON Lang HI")
      problem = problem_fixture()

      en_meta = %{"text" => "What is 2+2?"}
      hi_meta = %{"text" => "2+2 क्या है?"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      rendered =
        ResourceJSON.problem_lang(%{
          resource: problem,
          meta_data: en_meta,
          lang_code: "zke",
          resource_curriculum: %{
            curriculum_id: 1,
            grade_id: 1,
            subject_id: 1,
            difficulty_level: "medium"
          }
        })

      assert rendered.meta_data == en_meta
      assert rendered.lang_code == "zke"

      assert rendered.lang_versions == [
               %{lang_code: "zke", meta_data: en_meta},
               %{lang_code: "zkh", meta_data: hi_meta}
             ]
    end
  end
end
