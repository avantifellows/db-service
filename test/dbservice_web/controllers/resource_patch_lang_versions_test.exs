defmodule DbserviceWeb.ResourcePatchLangVersionsTest do
  @moduledoc """
  PATCH /api/resource/:id must return `lang_versions` in the response so the
  frontend gets the synced set of languages back (see #614 review). The
  representation is shared with the problem GET endpoints (#612).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Curriculums
  alias Dbservice.Languages
  alias Dbservice.ResourceCurriculums
  alias Dbservice.Resources

  defp language_fixture(code, name) do
    {:ok, language} = Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  defp curriculum_fixture do
    {:ok, curriculum} = Curriculums.create_curriculum(%{"name" => "Curriculum", "code" => "CURR"})
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

  describe "PATCH /api/resource/:id with lang_versions" do
    test "response includes every synced language in lang_versions", %{conn: conn} do
      language_fixture("pae", "PA EN")
      language_fixture("pah", "PA HI")
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      en_meta = %{"text" => "patch en"}
      hi_meta = %{"text" => "patch hi"}

      conn =
        patch(conn, ~p"/api/resource/#{problem.id}", %{
          "lang_versions" => [
            %{"lang_code" => "pae", "meta_data" => en_meta},
            %{"lang_code" => "pah", "meta_data" => hi_meta}
          ]
        })

      body = json_response(conn, 200)

      assert body["lang_versions"] == [
               %{"lang_code" => "pae", "meta_data" => en_meta},
               %{"lang_code" => "pah", "meta_data" => hi_meta}
             ]
    end

    test "lang_versions reflects a language removed by the sync", %{conn: conn} do
      language_fixture("pbe", "PB EN")
      language_fixture("pbh", "PB HI")
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      # Seed both languages...
      patch(conn, ~p"/api/resource/#{problem.id}", %{
        "lang_versions" => [
          %{"lang_code" => "pbe", "meta_data" => %{"text" => "en"}},
          %{"lang_code" => "pbh", "meta_data" => %{"text" => "hi"}}
        ]
      })

      # ...then PATCH with only English; Hindi should be dropped from the response.
      conn =
        patch(conn, ~p"/api/resource/#{problem.id}", %{
          "lang_versions" => [%{"lang_code" => "pbe", "meta_data" => %{"text" => "en only"}}]
        })

      body = json_response(conn, 200)

      assert body["lang_versions"] == [
               %{"lang_code" => "pbe", "meta_data" => %{"text" => "en only"}}
             ]

      assert length(body["lang_versions"]) == 1
    end
  end
end
