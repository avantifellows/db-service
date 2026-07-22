defmodule DbserviceWeb.ProblemAllLanguagesTest do
  @moduledoc """
  Covers the lang_code-free (all-languages) variants of the problem GET
  endpoints. Each returns every problem once with all languages in
  `lang_versions`, so the frontend can filter client-side (see #612 review).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Curriculums
  alias Dbservice.Languages
  alias Dbservice.ProblemLanguages
  alias Dbservice.ResourceCurriculums
  alias Dbservice.ResourceTopics
  alias Dbservice.Resources
  alias Dbservice.Topics

  defp language_fixture(code, name) do
    {:ok, language} = Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
  end

  defp test_fixture(problem_ids) do
    type_params = %{
      "subjects" => [
        %{
          "sections" => [
            %{"compulsory" => %{"problems" => Enum.map(problem_ids, &%{"id" => &1})}}
          ]
        }
      ]
    }

    {:ok, resource} = Resources.create_resource(%{"type" => "test", "type_params" => type_params})
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

  defp curriculum_fixture do
    {:ok, curriculum} = Curriculums.create_curriculum(%{"name" => "Curriculum", "code" => "CURR"})
    curriculum
  end

  defp topic_fixture do
    {:ok, topic} = Topics.create_topic(%{"code" => "TOP-#{System.unique_integer([:positive])}"})
    topic
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

  defp resource_topic_fixture(resource, topic) do
    {:ok, rt} =
      ResourceTopics.create_resource_topic(%{resource_id: resource.id, topic_id: topic.id})

    rt
  end

  describe "GET /api/resource/problem/:problem_id/:curriculum_id" do
    test "returns the problem with all languages and no single-language fields", %{conn: conn} do
      en = language_fixture("aae", "AA EN")
      hi = language_fixture("aah", "AA HI")
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      en_meta = %{"text" => "What is 2+2?"}
      hi_meta = %{"text" => "2+2 क्या है?"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      conn = get(conn, ~p"/api/resource/problem/#{problem.id}/#{curriculum.id}")
      body = json_response(conn, 200)

      assert body["id"] == problem.id
      # No single language requested, so the flat fields are empty...
      assert body["meta_data"] == nil
      assert body["lang_code"] == nil
      # ...and every language is carried in lang_versions.
      assert body["lang_versions"] == [
               %{"lang_code" => "aae", "meta_data" => en_meta},
               %{"lang_code" => "aah", "meta_data" => hi_meta}
             ]
    end

    test "404 when the curriculum is not linked to the problem", %{conn: conn} do
      problem = problem_fixture()
      other_curriculum = curriculum_fixture()

      conn = get(conn, ~p"/api/resource/problem/#{problem.id}/#{other_curriculum.id}")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/resource/test/:id/problems (no lang_code)" do
    test "returns each test problem once with all languages", %{conn: conn} do
      en = language_fixture("abe", "AB EN")
      hi = language_fixture("abh", "AB HI")
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      en_meta = %{"text" => "test EN"}
      hi_meta = %{"text" => "test HI"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      test = test_fixture([problem.id])

      conn = get(conn, ~p"/api/resource/test/#{test.id}/problems?curriculum_id=#{curriculum.id}")
      body = json_response(conn, 200)

      assert [entry] = body
      assert entry["id"] == problem.id

      assert entry["lang_versions"] == [
               %{"lang_code" => "abe", "meta_data" => en_meta},
               %{"lang_code" => "abh", "meta_data" => hi_meta}
             ]
    end
  end

  describe "GET /api/problems (no lang_code)" do
    test "returns each problem once (deduped) with all languages", %{conn: conn} do
      en = language_fixture("ace", "AC EN")
      hi = language_fixture("ach", "AC HI")
      curriculum = curriculum_fixture()
      topic = topic_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)
      resource_topic_fixture(problem, topic)

      en_meta = %{"text" => "topic EN"}
      hi_meta = %{"text" => "topic HI"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      conn = get(conn, ~p"/api/problems?topic_id=#{topic.id}&curriculum_id=#{curriculum.id}")
      body = json_response(conn, 200)

      # Two languages, but the problem appears exactly once.
      assert [entry] = body
      assert entry["id"] == problem.id

      assert entry["lang_versions"] == [
               %{"lang_code" => "ace", "meta_data" => en_meta},
               %{"lang_code" => "ach", "meta_data" => hi_meta}
             ]
    end

    test "still filters to a single language when lang_code is given", %{conn: conn} do
      en = language_fixture("ade", "AD EN")
      hi = language_fixture("adh", "AD HI")
      curriculum = curriculum_fixture()
      topic = topic_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)
      resource_topic_fixture(problem, topic)

      en_meta = %{"text" => "single EN"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, %{"text" => "single HI"})

      conn =
        get(
          conn,
          ~p"/api/problems?topic_id=#{topic.id}&curriculum_id=#{curriculum.id}&lang_code=ade"
        )

      body = json_response(conn, 200)
      assert [entry] = body
      # Backward-compatible: flat meta_data is the requested language.
      assert entry["meta_data"] == en_meta
    end
  end

  describe "GET /api/problems/search (no lang_code)" do
    test "dedupes a problem that matches in multiple languages", %{conn: conn} do
      en = language_fixture("aee", "AE EN")
      hi = language_fixture("aeh", "AE HI")
      curriculum = curriculum_fixture()
      problem = problem_fixture()
      resource_curriculum_fixture(problem, curriculum)

      # Same unique term in both languages -> two problem_lang rows match.
      term = "zzsearchtoken"
      en_meta = %{"text" => "english #{term}"}
      hi_meta = %{"text" => "hindi #{term}"}
      problem_language_fixture(problem, en, en_meta)
      problem_language_fixture(problem, hi, hi_meta)

      conn = get(conn, ~p"/api/problems/search?search=#{term}")
      body = json_response(conn, 200)

      assert [entry] = body
      assert entry["id"] == problem.id
      assert get_resp_header(conn, "x-total-count") == ["1"]

      assert entry["lang_versions"] == [
               %{"lang_code" => "aee", "meta_data" => en_meta},
               %{"lang_code" => "aeh", "meta_data" => hi_meta}
             ]
    end
  end
end
