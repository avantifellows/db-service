defmodule DbserviceWeb.CollegeBranchNamesTest do
  use DbserviceWeb.ConnCase

  # Unique ids/names to avoid colliding with any pre-existing data in the test DB.
  defp college_fixture(college_id, name) do
    {:ok, college} =
      Dbservice.Colleges.create_college(%{"college_id" => college_id, "name" => name})

    college
  end

  defp branch_fixture(branch_id, name) do
    {:ok, branch} =
      Dbservice.Branches.create_branch(%{"branch_id" => branch_id, "name" => name})

    branch
  end

  describe "GET /api/college/names" do
    test "returns only college_id and name, sorted by name", %{conn: conn} do
      college_fixture("ZNAM2", "ZName Beta College")
      college_fixture("ZNAM1", "ZName Alpha College")

      conn = get(conn, ~p"/api/college/names", %{"name" => "zname"})

      assert [
               %{"college_id" => "ZNAM1", "name" => "ZName Alpha College"},
               %{"college_id" => "ZNAM2", "name" => "ZName Beta College"}
             ] = json_response(conn, 200)
    end

    test "filters by case-insensitive name substring", %{conn: conn} do
      college_fixture("ZFIL1", "ZFilter Institute of Technology")
      college_fixture("ZFIL2", "ZFilter Medical College")

      conn = get(conn, ~p"/api/college/names", %{"name" => "zfilter medical"})

      assert [%{"college_id" => "ZFIL2"}] = json_response(conn, 200)
    end

    test "supports limit and offset", %{conn: conn} do
      college_fixture("ZPAG1", "ZPage College A")
      college_fixture("ZPAG2", "ZPage College B")
      college_fixture("ZPAG3", "ZPage College C")

      conn =
        get(conn, ~p"/api/college/names", %{"name" => "zpage", "limit" => "2", "offset" => "1"})

      assert [
               %{"college_id" => "ZPAG2"},
               %{"college_id" => "ZPAG3"}
             ] = json_response(conn, 200)
    end
  end

  describe "GET /api/branch/names" do
    test "returns only id, branch_id and name, sorted by name", %{conn: conn} do
      b2 = branch_fixture("ZBR2", "ZBranch Mechanical")
      b1 = branch_fixture("ZBR1", "ZBranch Computer Science")

      conn = get(conn, ~p"/api/branch/names", %{"name" => "zbranch"})

      assert [
               %{"id" => id1, "branch_id" => "ZBR1", "name" => "ZBranch Computer Science"},
               %{"id" => id2, "branch_id" => "ZBR2", "name" => "ZBranch Mechanical"}
             ] = json_response(conn, 200)

      assert id1 == b1.id
      assert id2 == b2.id
    end

    test "does not shadow GET /api/branch/:id", %{conn: conn} do
      branch = branch_fixture("ZSHW1", "ZShow Branch")

      conn = get(conn, ~p"/api/branch/#{branch.id}")

      assert %{"branch_id" => "ZSHW1", "name" => "ZShow Branch", "duration" => _} =
               json_response(conn, 200)
    end
  end
end
