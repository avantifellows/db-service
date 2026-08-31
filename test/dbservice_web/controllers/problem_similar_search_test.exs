defmodule DbserviceWeb.ProblemSimilarSearchTest do
  @moduledoc """
  POST /api/problems/similar-search — fuzzy/similarity duplicate detection
  (issue #700). Matching is scoped per language and filtered to > 0.75 (the
  pg_trgm `%` operator is strictly greater than the threshold).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.Languages
  alias Dbservice.ProblemLanguages
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

  defp problem_fixture do
    {:ok, resource} = Resources.create_resource(%{"type" => "problem", "type_params" => %{}})
    resource
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
end
