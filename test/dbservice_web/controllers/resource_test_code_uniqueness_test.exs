defmodule DbserviceWeb.ResourceTestCodeUniquenessTest do
  use DbserviceWeb.ConnCase

  alias Dbservice.Repo
  alias Dbservice.Resources.Resource

  # Year 98 keeps these codes clear of anything already seeded in the test
  # database, so a rejected update can only be caused by the fixtures below.
  @year "98"
  @message "This test code has already been used."

  defp resource_fixture(attrs) do
    Repo.insert!(struct(%Resource{type: "test", type_params: %{}}, attrs))
  end

  defp patch_resource(conn, resource, params) do
    patch(conn, ~p"/api/resource/#{resource.id}", params)
  end

  describe "PATCH /api/resource with a test code" do
    test "rejects a code another resource already uses", %{conn: conn} do
      resource_fixture(code: "JN-P-1-#{@year}")
      test_b = resource_fixture(code: "JN-P-2-#{@year}")

      conn = patch_resource(conn, test_b, %{"code" => "JN-P-1-#{@year}"})

      assert %{"errors" => %{"message" => @message}} = json_response(conn, 422)
      assert Repo.get!(Resource, test_b.id).code == "JN-P-2-#{@year}"
    end

    test "accepts a code nothing else uses", %{conn: conn} do
      test_a = resource_fixture(code: "JN-P-3-#{@year}")

      conn = patch_resource(conn, test_a, %{"code" => "JN-P-4-#{@year}"})

      assert json_response(conn, 200)
      assert Repo.get!(Resource, test_a.id).code == "JN-P-4-#{@year}"
    end

    test "accepts the resource's own code", %{conn: conn} do
      test_a = resource_fixture(code: "JN-P-5-#{@year}")

      conn = patch_resource(conn, test_a, %{"code" => "JN-P-5-#{@year}"})

      assert json_response(conn, 200)
    end

    # Duplicates predating this check are already in the database, so a test
    # that shares its code with another one must stay editable.
    test "accepts an existing duplicate's own code", %{conn: conn} do
      resource_fixture(code: "JN-P-6-#{@year}")
      duplicate = resource_fixture(code: "JN-P-6-#{@year}")

      conn =
        patch_resource(conn, duplicate, %{
          "code" => "JN-P-6-#{@year}",
          "source" => "updated"
        })

      assert json_response(conn, 200)
      assert Repo.get!(Resource, duplicate.id).source == "updated"
    end

    test "accepts an update that leaves the code out", %{conn: conn} do
      resource_fixture(code: "JN-P-7-#{@year}")
      duplicate = resource_fixture(code: "JN-P-7-#{@year}")

      conn = patch_resource(conn, duplicate, %{"source" => "untouched code"})

      assert json_response(conn, 200)
      assert Repo.get!(Resource, duplicate.id).source == "untouched code"
    end

    test "leaves non-test resources alone", %{conn: conn} do
      resource_fixture(code: "JN-P-8-#{@year}")
      problem = resource_fixture(code: "JN-P-9-#{@year}", type: "problem")

      conn = patch_resource(conn, problem, %{"code" => "JN-P-8-#{@year}"})

      assert json_response(conn, 200)
      assert Repo.get!(Resource, problem.id).code == "JN-P-8-#{@year}"
    end

    test "rejects a resource being turned into a test on a used code", %{conn: conn} do
      resource_fixture(code: "JN-P-10-#{@year}")
      problem = resource_fixture(code: "JN-P-11-#{@year}", type: "problem")

      conn =
        patch_resource(conn, problem, %{"type" => "test", "code" => "JN-P-10-#{@year}"})

      assert %{"errors" => %{"message" => @message}} = json_response(conn, 422)
    end
  end
end
