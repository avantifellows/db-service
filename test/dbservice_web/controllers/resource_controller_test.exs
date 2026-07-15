defmodule DbserviceWeb.ResourceControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  alias Dbservice.Repo
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Resources.Resource

  # Unique codes to avoid colliding with any pre-existing language in the test DB.
  defp language_fixture(code, name) do
    {:ok, language} = Dbservice.Languages.create_language(%{"name" => name, "code" => code})
    language
  end

  defp problem_lang_rows(resource_id) do
    from(pl in ProblemLanguage, where: pl.res_id == ^resource_id, order_by: [asc: pl.id])
    |> Repo.all()
  end

  describe "POST /api/resource with lang_versions" do
    test "creates one problem_lang row per lang_versions entry", %{conn: conn} do
      en = language_fixture("rce", "Resource Create EN")
      hi = language_fixture("rch", "Resource Create HI")

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "subtype" => "mcq_single_answer",
          "type_params" => %{},
          "lang_versions" => [
            %{"lang_code" => "rce", "meta_data" => %{"text" => "What is 2+2?"}},
            %{"lang_code" => "rch", "meta_data" => %{"text" => "2+2 क्या है?"}}
          ]
        })

      assert %{"id" => id} = json_response(conn, 201)

      assert [first, second] = problem_lang_rows(id)
      assert first.lang_id == en.id
      assert first.meta_data == %{"text" => "What is 2+2?"}
      assert second.lang_id == hi.id
      assert second.meta_data == %{"text" => "2+2 क्या है?"}
    end

    test "old flat lang_code + meta_data format keeps working", %{conn: conn} do
      en = language_fixture("rco", "Resource Create Old")

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "subtype" => "mcq_single_answer",
          "type_params" => %{},
          "lang_code" => "rco",
          "meta_data" => %{"text" => "Old format"}
        })

      assert %{"id" => id} = json_response(conn, 201)

      assert [row] = problem_lang_rows(id)
      assert row.lang_id == en.id
      assert row.meta_data == %{"text" => "Old format"}
    end

    test "lang_versions takes precedence over flat lang_code + meta_data", %{conn: conn} do
      language_fixture("rcp", "Resource Create Precedence")

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "subtype" => "mcq_single_answer",
          "type_params" => %{},
          "lang_code" => "rcp",
          "meta_data" => %{"text" => "flat"},
          "lang_versions" => [
            %{"lang_code" => "rcp", "meta_data" => %{"text" => "from lang_versions"}}
          ]
        })

      assert %{"id" => id} = json_response(conn, 201)

      assert [row] = problem_lang_rows(id)
      assert row.meta_data == %{"text" => "from lang_versions"}
    end

    test "rejects an unknown lang_code and rolls back the whole resource", %{conn: conn} do
      language_fixture("rcu", "Resource Create Unknown")
      before_count = Repo.aggregate(Resource, :count)

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "subtype" => "mcq_single_answer",
          "type_params" => %{},
          "lang_versions" => [
            %{"lang_code" => "rcu", "meta_data" => %{"text" => "ok"}},
            %{"lang_code" => "nope", "meta_data" => %{"text" => "bad"}}
          ]
        })

      assert %{"error" => error} = json_response(conn, 422)
      assert error =~ "nope"
      assert Repo.aggregate(Resource, :count) == before_count
    end

    test "comprehension problem with lang_versions shares one paragraph across languages",
         %{conn: conn} do
      language_fixture("rcf", "Resource Comprehension EN")
      language_fixture("rcg", "Resource Comprehension HI")

      conn =
        post(conn, ~p"/api/resource", %{
          "type" => "problem",
          "subtype" => "comprehension",
          "type_params" => %{},
          "paragraph" => "Read the following passage...",
          "lang_versions" => [
            %{"lang_code" => "rcf", "meta_data" => %{"text" => "Q en"}},
            %{"lang_code" => "rcg", "meta_data" => %{"text" => "Q hi"}}
          ]
        })

      assert %{"id" => id} = json_response(conn, 201)

      assert [first, second] = problem_lang_rows(id)
      assert is_integer(first.paragraph_id)
      assert first.paragraph_id == second.paragraph_id
    end
  end

  describe "POST /api/resources/problems/batch with lang_versions" do
    test "creates comprehension problems from lang_versions sharing the batch paragraph",
         %{conn: conn} do
      language_fixture("rcb", "Resource Batch EN")

      conn =
        post(conn, ~p"/api/resources/problems/batch", %{
          "paragraph" => "Shared passage for the comprehension set.",
          "problems" => [
            %{
              "subtype" => "comprehension",
              "type_params" => %{},
              "lang_versions" => [
                %{"lang_code" => "rcb", "meta_data" => %{"text" => "Q1"}}
              ]
            },
            %{
              "subtype" => "comprehension",
              "type_params" => %{},
              "lang_versions" => [
                %{"lang_code" => "rcb", "meta_data" => %{"text" => "Q2"}}
              ]
            }
          ]
        })

      assert %{"created" => [c1, c2], "failed" => []} = json_response(conn, 200)

      [row1] = problem_lang_rows(c1["id"])
      [row2] = problem_lang_rows(c2["id"])
      assert row1.meta_data == %{"text" => "Q1"}
      assert row2.meta_data == %{"text" => "Q2"}
      # Both problems link to the single paragraph created for the batch
      assert row1.paragraph_id == row2.paragraph_id
      assert is_integer(row1.paragraph_id)
    end

    test "old flat format entries keep working and unknown languages fail per index",
         %{conn: conn} do
      language_fixture("rcz", "Resource Batch Old")

      conn =
        post(conn, ~p"/api/resources/problems/batch", %{
          "paragraph" => "Shared passage.",
          "problems" => [
            %{
              "subtype" => "comprehension",
              "type_params" => %{},
              "lang_code" => "rcz",
              "meta_data" => %{"text" => "Old Q"}
            },
            %{
              "subtype" => "comprehension",
              "type_params" => %{},
              "lang_versions" => [
                %{"lang_code" => "nope", "meta_data" => %{"text" => "bad"}}
              ]
            }
          ]
        })

      assert %{"created" => [c1], "failed" => [failure]} = json_response(conn, 200)

      [row1] = problem_lang_rows(c1["id"])
      assert row1.meta_data == %{"text" => "Old Q"}
      assert failure["index"] == 1
      assert failure["error"] =~ "nope"
    end
  end
end
