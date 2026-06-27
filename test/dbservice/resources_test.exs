defmodule Dbservice.ResourcesTest do
  use Dbservice.DataCase, async: true

  alias Dbservice.Languages.Language
  alias Dbservice.Repo
  alias Dbservice.Resources
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Resources.Resource

  describe "get_problems_by_test_and_language/3" do
    test "returns problems in the order saved on the test" do
      language =
        Repo.insert!(%Language{
          name: "English",
          code: "test_en_#{System.unique_integer([:positive])}"
        })

      first = insert_problem!(language.id)
      second = insert_problem!(language.id)
      third = insert_problem!(language.id)

      test_resource =
        Repo.insert!(%Resource{
          type: "test",
          type_params: %{
            "subjects" => [
              %{
                "sections" => [
                  %{
                    "compulsory" => %{
                      "problems" => [
                        %{"id" => second.id},
                        %{"id" => first.id},
                        %{"id" => third.id}
                      ]
                    }
                  }
                ]
              }
            ]
          }
        })

      problems = Resources.get_problems_by_test_and_language(test_resource.id, language.code, 1)

      assert Enum.map(problems, & &1.resource.id) == [second.id, first.id, third.id]
    end
  end

  defp insert_problem!(language_id) do
    resource =
      Repo.insert!(%Resource{
        type: "problem",
        type_params: %{}
      })

    Repo.insert!(%ProblemLanguage{
      res_id: resource.id,
      lang_id: language_id,
      meta_data: %{}
    })

    resource
  end
end
