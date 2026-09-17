defmodule DbserviceWeb.ResourceTestSequencesTest do
  use DbserviceWeb.ConnCase

  alias Dbservice.Repo
  alias Dbservice.Resources.Resource

  # Year 97 keeps these fixtures clear of any test codes already seeded in the
  # test database, so the assertions below are exact rather than "contains".
  @year "97"

  defp resource_fixture(attrs) do
    Repo.insert!(struct(%Resource{type: "test", type_params: %{}}, attrs))
  end

  defp used_sequences(conn, params) do
    conn
    |> get(~p"/api/resources/test-sequences?#{params}")
    |> json_response(200)
    |> Map.fetch!("used_sequences")
  end

  describe "GET /api/resources/test-sequences" do
    test "returns the used sequence numbers sorted, gaps included", %{conn: conn} do
      for sequence <- [10, 1, 7, 2, 3] do
        resource_fixture(code: "JN-P-#{sequence}-#{@year}")
      end

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) ==
               [1, 2, 3, 7, 10]
    end

    test "returns an empty list when nothing is used yet", %{conn: conn} do
      assert used_sequences(conn, %{program: "JN", type_code: "FST", year: @year}) == []
    end

    test "ignores codes from another program, type code, or year", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      resource_fixture(code: "MH-P-2-#{@year}")
      resource_fixture(code: "JN-CT-3-#{@year}")
      resource_fixture(code: "JN-P-4-96")

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) == [1]
    end

    test "ignores resources that are not tests", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      resource_fixture(code: "JN-P-2-#{@year}", type: "problem")

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) == [1]
    end

    test "ignores codes that are not exactly four hyphenated parts", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      # The LIKE wildcard spans hyphens, so these match the pattern but are not
      # `<program>-<type_code>-<sequence>-<year>` codes.
      resource_fixture(code: "JN-P-2-3-#{@year}")
      resource_fixture(code: "JN-P-#{@year}")

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) == [1]
    end

    test "ignores codes whose sequence part is not a number", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      resource_fixture(code: "JN-P-draft-#{@year}")
      resource_fixture(code: "JN-P--#{@year}")
      resource_fixture(code: "JN-P-2x-#{@year}")

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) == [1]
    end

    test "deduplicates a sequence number used by more than one resource", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      resource_fixture(code: "JN-P-1-#{@year}")

      assert used_sequences(conn, %{program: "JN", type_code: "P", year: @year}) == [1]
    end

    test "matches case sensitively, so mixed-case type codes stay distinct", %{conn: conn} do
      resource_fixture(code: "JN-MoT-5-#{@year}")
      resource_fixture(code: "JN-MT-6-#{@year}")

      assert used_sequences(conn, %{program: "JN", type_code: "MoT", year: @year}) == [5]
      assert used_sequences(conn, %{program: "JN", type_code: "MT", year: @year}) == [6]
      assert used_sequences(conn, %{program: "JN", type_code: "mot", year: @year}) == []
    end

    test "accepts a program or type code that is not in today's list", %{conn: conn} do
      resource_fixture(code: "ZZ-XYZ-1-#{@year}")

      assert used_sequences(conn, %{program: "ZZ", type_code: "XYZ", year: @year}) == [1]
    end
  end

  describe "GET /api/resources/test-sequences validation" do
    test "rejects a missing parameter", %{conn: conn} do
      for params <- [
            %{type_code: "P", year: @year},
            %{program: "JN", year: @year},
            %{program: "JN", type_code: "P"}
          ] do
        conn = get(conn, ~p"/api/resources/test-sequences?#{params}")
        assert %{"error" => error} = json_response(conn, 400)
        assert is_binary(error)
      end
    end

    test "rejects LIKE wildcards instead of treating them as a pattern", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")

      for params <- [
            %{program: "%", type_code: "P", year: @year},
            %{program: "JN", type_code: "_", year: @year}
          ] do
        conn = get(conn, ~p"/api/resources/test-sequences?#{params}")
        assert %{"error" => _} = json_response(conn, 400)
      end
    end

    test "rejects a year that is not two digits", %{conn: conn} do
      for year <- ["2026", "6", "ab", ""] do
        conn =
          get(
            conn,
            ~p"/api/resources/test-sequences?#{%{program: "JN", type_code: "P", year: year}}"
          )

        assert %{"error" => error} = json_response(conn, 400)
        assert error =~ "year"
      end
    end
  end
end
