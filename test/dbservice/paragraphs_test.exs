defmodule Dbservice.ParagraphsTest do
  use Dbservice.DataCase, async: true

  alias Dbservice.Languages.Language
  alias Dbservice.Paragraphs
  alias Dbservice.Repo
  alias Dbservice.Resources.Paragraph
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Resources.Resource

  describe "update_paragraphs_for_resources/2" do
    setup do
      paragraph = Repo.insert!(%Paragraph{body: "original passage"})

      resource =
        Repo.insert!(%Resource{
          type: "problem",
          subtype: "comprehension",
          type_params: %{}
        })

      en =
        Repo.insert!(%Language{
          name: "English",
          code: "test_en_#{System.unique_integer([:positive])}"
        })

      hi =
        Repo.insert!(%Language{
          name: "Hindi",
          code: "test_hi_#{System.unique_integer([:positive])}"
        })

      Repo.insert!(%ProblemLanguage{
        res_id: resource.id,
        lang_id: en.id,
        paragraph_id: paragraph.id,
        meta_data: %{}
      })

      Repo.insert!(%ProblemLanguage{
        res_id: resource.id,
        lang_id: hi.id,
        paragraph_id: paragraph.id,
        meta_data: %{}
      })

      %{paragraph: paragraph, resource: resource}
    end

    test "updates the shared paragraph body when multiple problem_lang rows share it",
         %{paragraph: paragraph, resource: resource} do
      assert :ok =
               Paragraphs.update_paragraphs_for_resources([resource.id], "new passage body")

      assert Repo.get!(Paragraph, paragraph.id).body == "new passage body"
    end

    test "no-ops on empty resource id list" do
      assert :ok = Paragraphs.update_paragraphs_for_resources([], "ignored")
    end

    test "no-ops when body is not a binary",
         %{paragraph: paragraph, resource: resource} do
      assert :ok = Paragraphs.update_paragraphs_for_resources([resource.id], nil)
      assert Repo.get!(Paragraph, paragraph.id).body == "original passage"
    end
  end
end
