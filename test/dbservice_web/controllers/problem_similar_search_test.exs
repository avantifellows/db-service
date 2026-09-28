defmodule DbserviceWeb.ProblemSimilarSearchTest do
  @moduledoc """
  POST /api/problems/similar-search — fuzzy/similarity duplicate detection
  (issue #700). Matching is scoped per language and filtered to > 0.75 (the
  pg_trgm `%` operator is strictly greater than the threshold).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.CmsStatuses
  alias Dbservice.Curriculums
  alias Dbservice.Languages
  alias Dbservice.ProblemLanguages
  alias Dbservice.ResourceCurriculums
  alias Dbservice.Resources

  # Long-ish stems so trigram scores are stable (calibrated: the near-duplicate
  # below scores ~0.86, the unrelated text ~0.04).
  @electric_vacuum "the electric field associated with an electromagnetic wave travelling in vacuum"
  @electric_air "the electric field associated with an electromagnetic wave travelling in air"
  @unrelated "photosynthesis converts carbon dioxide and water into glucose using sunlight"

  defp language_fixture(code) do
    {:ok, language} = Languages.create_language(%{"name" => code, "code" => code})
    language
  end

  defp problem_fixture(attrs \\ %{}) do
    {:ok, resource} =
      Resources.create_resource(Map.merge(%{"type" => "problem", "type_params" => %{}}, attrs))

    resource
  end

  defp curriculum_fixture(code) do
    {:ok, curriculum} = Curriculums.create_curriculum(%{"name" => code, "code" => code})
    curriculum
  end

  # grade_id/subject_id are nullable and irrelevant to curriculum scoping, so the
  # mapping is left at its minimum: a resource in a curriculum.
  defp map_to_curriculum(resource, curriculum, difficulty_level \\ nil) do
    {:ok, rc} =
      ResourceCurriculums.create_resource_curriculum(%{
        resource_id: resource.id,
        curriculum_id: curriculum.id,
        difficulty_level: difficulty_level
      })

    rc
  end

  # "archived" is seeded in some environments and not others; cms_status.name is
  # uniquely indexed, so reuse the row when it is already there.
  defp archived_status do
    case CmsStatuses.get_cms_status_by_name("archived") do
      nil ->
        {:ok, status} = CmsStatuses.create_cms_status(%{"name" => "archived"})
        status

      status ->
        status
    end
  end

  # Creates a problem_lang row; question_plain_text is derived automatically from
  # meta_data["text"] by the changeset. Text is wrapped in HTML to exercise the
  # end-to-end normalization.
  defp problem_lang_fixture(resource, language, text) do
    {:ok, pl} =
      ProblemLanguages.create_problem_language(%{
        res_id: resource.id,
        lang_id: language.id,
        meta_data: %{"text" => "<div>#{text}</div>"}
      })

    pl
  end

  defp similar(conn, languages) do
    conn
    |> post(~p"/api/problems/similar-search", %{"languages" => languages})
    |> json_response(200)
  end

  defp similar(conn, languages, curriculum_id) do
    conn
    |> post(~p"/api/problems/similar-search", %{
      "languages" => languages,
      "curriculum_id" => curriculum_id
    })
    |> json_response(200)
  end

  describe "POST /api/problems/similar-search" do
    test "empty problem bank returns no matches", %{conn: conn} do
      language_fixture("q1e")

      body = similar(conn, [%{"lang_code" => "q1e", "text" => "<div>#{@electric_vacuum}</div>"}])
      assert body == %{"problems" => []}
    end

    test "returns an exact duplicate with match_score 1.0", %{conn: conn} do
      en = language_fixture("q2e")
      problem = problem_fixture()
      problem_lang_fixture(problem, en, @electric_vacuum)

      body = similar(conn, [%{"lang_code" => "q2e", "text" => "<div>#{@electric_vacuum}</div>"}])

      assert [match] = body["problems"]
      assert match["id"] == problem.id
      assert match["code"] == problem.code
      assert match["lang_code"] == "q2e"
      assert match["match_score"] == 1.0
    end

    test "returns a near-duplicate (> 0.75, < 1.0) and excludes unrelated ones", %{conn: conn} do
      en = language_fixture("q3e")
      near = problem_fixture()
      unrelated = problem_fixture()
      problem_lang_fixture(near, en, @electric_vacuum)
      problem_lang_fixture(unrelated, en, @unrelated)

      # Query with a slightly different phrasing of the "near" problem.
      body = similar(conn, [%{"lang_code" => "q3e", "text" => "<div>#{@electric_air}</div>"}])

      ids = Enum.map(body["problems"], & &1["id"])
      assert near.id in ids
      refute unrelated.id in ids

      match = Enum.find(body["problems"], &(&1["id"] == near.id))
      assert match["match_score"] > 0.75
      assert match["match_score"] < 1.0
    end

    test "matches per language: only the language with a duplicate returns a hit", %{conn: conn} do
      en = language_fixture("q4e")
      _hi = language_fixture("q4h")
      problem = problem_fixture()
      # Only the English text exists in the bank.
      problem_lang_fixture(problem, en, @electric_vacuum)

      body =
        similar(conn, [
          %{"lang_code" => "q4e", "text" => "<div>#{@electric_vacuum}</div>"},
          %{"lang_code" => "q4h", "text" => "<div>#{@electric_vacuum}</div>"}
        ])

      assert [match] = body["problems"]
      assert match["lang_code"] == "q4e"
      assert match["id"] == problem.id
    end

    test "does not match the same text across a different language", %{conn: conn} do
      en = language_fixture("q5e")
      _hi = language_fixture("q5h")
      problem = problem_fixture()
      problem_lang_fixture(problem, en, @electric_vacuum)

      # Same text, but queried under a different lang_code — must not match the en row.
      body = similar(conn, [%{"lang_code" => "q5h", "text" => "<div>#{@electric_vacuum}</div>"}])
      assert body == %{"problems" => []}
    end

    test "unknown lang_code and blank text contribute nothing", %{conn: conn} do
      body =
        similar(conn, [
          %{"lang_code" => "nope", "text" => "<div>#{@electric_vacuum}</div>"},
          %{"lang_code" => "q6e", "text" => "<div></div>"}
        ])

      assert body == %{"problems" => []}
    end

    test "400 when languages is missing", %{conn: conn} do
      conn = post(conn, ~p"/api/problems/similar-search", %{})
      assert json_response(conn, 400)["error"] =~ "languages"
    end
  end

  describe "curriculum scoping (issue #745)" do
    test "curriculum_id keeps matches inside that curriculum", %{conn: conn} do
      en = language_fixture("c1e")
      physics = curriculum_fixture("c1-physics")
      chemistry = curriculum_fixture("c1-chemistry")

      in_scope = problem_fixture()
      out_of_scope = problem_fixture()
      map_to_curriculum(in_scope, physics)
      map_to_curriculum(out_of_scope, chemistry)

      # Identical text in both curricula — only the requested one may come back.
      problem_lang_fixture(in_scope, en, @electric_vacuum)
      problem_lang_fixture(out_of_scope, en, @electric_vacuum)

      body =
        similar(
          conn,
          [%{"lang_code" => "c1e", "text" => "<div>#{@electric_vacuum}</div>"}],
          physics.id
        )

      assert [match] = body["problems"]
      assert match["id"] == in_scope.id
    end

    test "omitting curriculum_id still matches across curricula", %{conn: conn} do
      en = language_fixture("c2e")
      physics = curriculum_fixture("c2-physics")
      chemistry = curriculum_fixture("c2-chemistry")

      one = problem_fixture()
      two = problem_fixture()
      map_to_curriculum(one, physics)
      map_to_curriculum(two, chemistry)
      problem_lang_fixture(one, en, @electric_vacuum)
      problem_lang_fixture(two, en, @electric_vacuum)

      body = similar(conn, [%{"lang_code" => "c2e", "text" => "<div>#{@electric_vacuum}</div>"}])

      ids = Enum.map(body["problems"], & &1["id"])
      assert one.id in ids
      assert two.id in ids
    end

    test "a problem mapped to the curriculum twice is returned once", %{conn: conn} do
      en = language_fixture("c3e")
      physics = curriculum_fixture("c3-physics")

      problem = problem_fixture()
      # Same curriculum, two mapping rows — a plain join would return it twice.
      map_to_curriculum(problem, physics, "easy")
      map_to_curriculum(problem, physics, "hard")
      problem_lang_fixture(problem, en, @electric_vacuum)

      body =
        similar(
          conn,
          [%{"lang_code" => "c3e", "text" => "<div>#{@electric_vacuum}</div>"}],
          physics.id
        )

      assert [match] = body["problems"]
      assert match["id"] == problem.id
    end

    test "a problem in no curriculum is invisible to a scoped search", %{conn: conn} do
      en = language_fixture("c4e")
      physics = curriculum_fixture("c4-physics")

      unmapped = problem_fixture()
      problem_lang_fixture(unmapped, en, @electric_vacuum)

      scoped =
        similar(
          conn,
          [%{"lang_code" => "c4e", "text" => "<div>#{@electric_vacuum}</div>"}],
          physics.id
        )

      assert scoped == %{"problems" => []}

      # ...but the unscoped fallback still finds it.
      unscoped =
        similar(conn, [%{"lang_code" => "c4e", "text" => "<div>#{@electric_vacuum}</div>"}])

      assert [%{"id" => id}] = unscoped["problems"]
      assert id == unmapped.id
    end

    test "curriculum_id sent as a string is accepted", %{conn: conn} do
      en = language_fixture("c5e")
      physics = curriculum_fixture("c5-physics")

      problem = problem_fixture()
      map_to_curriculum(problem, physics)
      problem_lang_fixture(problem, en, @electric_vacuum)

      body =
        similar(
          conn,
          [%{"lang_code" => "c5e", "text" => "<div>#{@electric_vacuum}</div>"}],
          to_string(physics.id)
        )

      assert [%{"id" => id}] = body["problems"]
      assert id == problem.id
    end
  end

  describe "archived problems (issue #745)" do
    test "an archived near-duplicate is not returned", %{conn: conn} do
      en = language_fixture("a1e")
      archived = problem_fixture(%{"cms_status_id" => archived_status().id})
      problem_lang_fixture(archived, en, @electric_vacuum)

      body = similar(conn, [%{"lang_code" => "a1e", "text" => "<div>#{@electric_vacuum}</div>"}])
      assert body == %{"problems" => []}
    end

    test "an archived problem is excluded inside a curriculum too", %{conn: conn} do
      en = language_fixture("a2e")
      physics = curriculum_fixture("a2-physics")

      archived = problem_fixture(%{"cms_status_id" => archived_status().id})
      live = problem_fixture()
      map_to_curriculum(archived, physics)
      map_to_curriculum(live, physics)
      problem_lang_fixture(archived, en, @electric_vacuum)
      problem_lang_fixture(live, en, @electric_vacuum)

      body =
        similar(
          conn,
          [%{"lang_code" => "a2e", "text" => "<div>#{@electric_vacuum}</div>"}],
          physics.id
        )

      assert [match] = body["problems"]
      assert match["id"] == live.id
    end

    test "a problem with no cms_status is still matched", %{conn: conn} do
      en = language_fixture("a3e")
      # Force the "archived" row to exist, so the filter is actually applied.
      archived_status()

      problem = problem_fixture()
      assert is_nil(problem.cms_status_id)
      problem_lang_fixture(problem, en, @electric_vacuum)

      body = similar(conn, [%{"lang_code" => "a3e", "text" => "<div>#{@electric_vacuum}</div>"}])

      assert [%{"id" => id}] = body["problems"]
      assert id == problem.id
    end

    test "a problem in a non-archived cms_status is still matched", %{conn: conn} do
      en = language_fixture("a4e")
      archived_status()
      {:ok, live_status} = CmsStatuses.create_cms_status(%{"name" => "a4-in-review"})

      problem = problem_fixture(%{"cms_status_id" => live_status.id})
      problem_lang_fixture(problem, en, @electric_vacuum)

      body = similar(conn, [%{"lang_code" => "a4e", "text" => "<div>#{@electric_vacuum}</div>"}])

      assert [%{"id" => id}] = body["problems"]
      assert id == problem.id
    end
  end
end
