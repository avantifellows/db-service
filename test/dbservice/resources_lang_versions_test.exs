defmodule Dbservice.ResourcesLangVersionsTest do
  use Dbservice.DataCase

  import Ecto.Query

  alias Dbservice.Paragraphs
  alias Dbservice.ProblemLanguages
  alias Dbservice.Repo
  alias Dbservice.Resources
  alias Dbservice.Resources.ProblemLanguage

  # Unique codes to avoid colliding with any pre-existing language in the test DB.
  defp language_fixture(code, name) do
    {:ok, language} = Dbservice.Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_fixture(attrs \\ %{}) do
    {:ok, resource} =
      Resources.create_resource(Map.merge(%{"type" => "problem", "type_params" => %{}}, attrs))

    resource
  end

  defp problem_language_fixture(resource, language, meta_data, extra \\ %{}) do
    {:ok, problem_lang} =
      ProblemLanguages.create_problem_language(
        Map.merge(
          %{res_id: resource.id, lang_id: language.id, meta_data: meta_data},
          extra
        )
      )

    problem_lang
  end

  defp problem_lang_rows(resource_id) do
    from(pl in ProblemLanguage, where: pl.res_id == ^resource_id, order_by: [asc: pl.id])
    |> Repo.all()
  end

  describe "update_resource_and_associations/2 with lang_versions" do
    test "updates existing languages and inserts new ones" do
      en = language_fixture("upe", "Update EN")
      hi = language_fixture("uph", "Update HI")
      problem = problem_fixture()
      problem_language_fixture(problem, en, %{"text" => "old en"})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "lang_versions" => [
            %{"lang_code" => "upe", "meta_data" => %{"text" => "new en"}},
            %{"lang_code" => "uph", "meta_data" => %{"text" => "new hi"}}
          ]
        })

      rows = problem_lang_rows(problem.id)
      assert Enum.map(rows, & &1.lang_id) == [en.id, hi.id]
      assert Enum.map(rows, & &1.meta_data) == [%{"text" => "new en"}, %{"text" => "new hi"}]
    end

    test "deletes languages absent from lang_versions" do
      en = language_fixture("dle", "Delete EN")
      hi = language_fixture("dlh", "Delete HI")
      problem = problem_fixture()
      problem_language_fixture(problem, en, %{"text" => "en"})
      problem_language_fixture(problem, hi, %{"text" => "hi"})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "lang_versions" => [
            %{"lang_code" => "dle", "meta_data" => %{"text" => "en updated"}}
          ]
        })

      assert [row] = problem_lang_rows(problem.id)
      assert row.lang_id == en.id
      assert row.meta_data == %{"text" => "en updated"}
    end

    test "skips unknown lang_codes without touching valid entries" do
      en = language_fixture("ske", "Skip EN")
      problem = problem_fixture()
      problem_language_fixture(problem, en, %{"text" => "en"})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "lang_versions" => [
            %{"lang_code" => "ske", "meta_data" => %{"text" => "en updated"}},
            %{"lang_code" => "nope", "meta_data" => %{"text" => "bad"}}
          ]
        })

      assert [row] = problem_lang_rows(problem.id)
      assert row.lang_id == en.id
      assert row.meta_data == %{"text" => "en updated"}
    end

    test "old flat lang_code + meta_data format keeps working" do
      en = language_fixture("ofe", "Old Flat EN")
      hi = language_fixture("ofh", "Old Flat HI")
      problem = problem_fixture()
      problem_language_fixture(problem, en, %{"text" => "en"})
      problem_language_fixture(problem, hi, %{"text" => "hi"})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "lang_code" => "ofe",
          "meta_data" => %{"text" => "en updated"}
        })

      # Only the addressed language changes; nothing is deleted on the old path
      rows = problem_lang_rows(problem.id)
      assert Enum.map(rows, & &1.meta_data) == [%{"text" => "en updated"}, %{"text" => "hi"}]
    end

    test "a new language of a comprehension problem joins the shared paragraph" do
      en = language_fixture("cpe", "Comprehension EN")
      hi = language_fixture("cph", "Comprehension HI")
      problem = problem_fixture(%{"subtype" => "comprehension"})
      {:ok, paragraph} = Paragraphs.create_paragraph(%{"body" => "Shared passage"})
      problem_language_fixture(problem, en, %{"text" => "en"}, %{paragraph_id: paragraph.id})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "lang_versions" => [
            %{"lang_code" => "cpe", "meta_data" => %{"text" => "en"}},
            %{"lang_code" => "cph", "meta_data" => %{"text" => "hi"}}
          ]
        })

      rows = problem_lang_rows(problem.id)
      assert Enum.map(rows, & &1.lang_id) == [en.id, hi.id]
      assert Enum.map(rows, & &1.paragraph_id) == [paragraph.id, paragraph.id]
    end

    test "paragraph body in the request updates the shared paragraph once" do
      en = language_fixture("pbe", "Paragraph EN")
      problem = problem_fixture(%{"subtype" => "comprehension"})
      {:ok, paragraph} = Paragraphs.create_paragraph(%{"body" => "Old passage"})
      problem_language_fixture(problem, en, %{"text" => "en"}, %{paragraph_id: paragraph.id})

      {:ok, _} =
        Resources.update_resource_and_associations(problem, %{
          "paragraph" => "New passage",
          "lang_versions" => [
            %{"lang_code" => "pbe", "meta_data" => %{"text" => "en updated"}}
          ]
        })

      assert Paragraphs.fetch_paragraph!(paragraph.id).body == "New passage"
      assert [row] = problem_lang_rows(problem.id)
      assert row.meta_data == %{"text" => "en updated"}
    end
  end
end
