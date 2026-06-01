defmodule DbserviceWeb.AcademicMentorshipMappingControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.AcademicMentorshipMappingFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists active mappings", %{conn: conn} do
      mapping = mapping_fixture()

      conn =
        get(
          conn,
          ~p"/api/academic-mentorship-mapping?mentor_ids=#{mapping.mentor_id}&academic_year=2025-2026"
        )

      resp = json_response(conn, 200)
      assert length(resp["mappings"]) == 1
      assert hd(resp["mappings"])["id"] == mapping.id
    end

    test "returns empty list when no mappings match", %{conn: conn} do
      conn =
        get(conn, ~p"/api/academic-mentorship-mapping?mentor_ids=99999&academic_year=2025-2026")

      assert %{"mappings" => []} = json_response(conn, 200)
    end

    test "excludes soft-deleted mappings", %{conn: conn} do
      mapping = mapping_fixture()

      Dbservice.AcademicMentorshipMappings.soft_delete_mapping(
        mapping.id,
        "admin@example.com"
      )

      conn =
        get(
          conn,
          ~p"/api/academic-mentorship-mapping?mentor_ids=#{mapping.mentor_id}&academic_year=2025-2026"
        )

      assert %{"mappings" => []} = json_response(conn, 200)
    end
  end

  describe "show" do
    test "returns mapping by id", %{conn: conn} do
      mapping = mapping_fixture()
      conn = get(conn, ~p"/api/academic-mentorship-mapping/#{mapping.id}")
      resp = json_response(conn, 200)
      assert resp["mapping"]["id"] == mapping.id
      assert resp["mapping"]["academic_year"] == "2025-2026"
    end

    test "returns 404 for non-existent mapping", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/api/academic-mentorship-mapping/999999")
      end
    end
  end

  describe "create" do
    test "creates mapping with valid data", %{conn: conn} do
      user = Dbservice.UsersFixtures.user_fixture()
      permission = user_permission_fixture()

      attrs = %{
        mentor_id: permission.id,
        mentee_id: user.id,
        academic_year: "2025-2026",
        created_by: "admin@example.com"
      }

      conn = post(conn, ~p"/api/academic-mentorship-mapping", attrs)
      resp = json_response(conn, 201)
      assert resp["mapping"]["mentor_id"] == permission.id
      assert resp["mapping"]["mentee_id"] == user.id
      assert resp["mapping"]["academic_year"] == "2025-2026"
    end

    test "returns 409 on duplicate active mapping", %{conn: conn} do
      mapping = mapping_fixture()

      attrs = %{
        mentor_id: mapping.mentor_id,
        mentee_id: mapping.mentee_id,
        academic_year: mapping.academic_year,
        created_by: "admin@example.com"
      }

      conn = post(conn, ~p"/api/academic-mentorship-mapping", attrs)
      assert json_response(conn, 409)["error"] =~ "already has an active mentor"
    end

    test "returns 422 with invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/academic-mentorship-mapping", %{mentor_id: nil})
      assert json_response(conn, 422)
    end
  end

  describe "batch_create" do
    test "creates multiple mappings in one transaction", %{conn: conn} do
      user1 = Dbservice.UsersFixtures.user_fixture()
      user2 = Dbservice.UsersFixtures.user_fixture()
      permission = user_permission_fixture()

      attrs = %{
        mappings: [
          %{
            mentor_id: permission.id,
            mentee_id: user1.id,
            academic_year: "2025-2026",
            created_by: "admin@example.com"
          },
          %{
            mentor_id: permission.id,
            mentee_id: user2.id,
            academic_year: "2025-2026",
            created_by: "admin@example.com"
          }
        ]
      }

      conn = post(conn, ~p"/api/academic-mentorship-mapping/batch", attrs)
      resp = json_response(conn, 201)
      assert resp["created"] == 2
      assert length(resp["mappings"]) == 2
    end

    test "returns 400 when mappings array missing", %{conn: conn} do
      conn = post(conn, ~p"/api/academic-mentorship-mapping/batch", %{})
      assert json_response(conn, 400)["error"] =~ "Missing required"
    end
  end

  describe "reassign" do
    test "atomically reassigns a mentee to a new mentor", %{conn: conn} do
      mapping = mapping_fixture()
      new_permission = user_permission_fixture()

      attrs = %{
        old_mapping_id: mapping.id,
        new_mentor_id: new_permission.id,
        updated_by: "admin@example.com"
      }

      conn = post(conn, ~p"/api/academic-mentorship-mapping/reassign", attrs)
      resp = json_response(conn, 200)
      assert resp["mapping"]["mentor_id"] == new_permission.id
      assert resp["mapping"]["mentee_id"] == mapping.mentee_id
    end

    test "returns 404 for non-existent mapping", %{conn: conn} do
      new_permission = user_permission_fixture()

      attrs = %{
        old_mapping_id: 999_999,
        new_mentor_id: new_permission.id,
        updated_by: "admin@example.com"
      }

      conn = post(conn, ~p"/api/academic-mentorship-mapping/reassign", attrs)
      assert json_response(conn, 404)["error"] =~ "not found"
    end

    test "returns 400 when required fields missing", %{conn: conn} do
      conn = post(conn, ~p"/api/academic-mentorship-mapping/reassign", %{})
      assert json_response(conn, 400)["error"] =~ "Missing required"
    end
  end

  describe "soft_delete" do
    test "soft-deletes a mapping", %{conn: conn} do
      mapping = mapping_fixture()

      conn =
        delete(conn, ~p"/api/academic-mentorship-mapping/#{mapping.id}", %{
          updated_by: "admin@example.com"
        })

      resp = json_response(conn, 200)
      assert resp["mapping"]["id"] == mapping.id
      assert resp["mapping"]["deleted_at"] != nil
    end

    test "returns 404 for already-deleted mapping", %{conn: conn} do
      mapping = mapping_fixture()

      Dbservice.AcademicMentorshipMappings.soft_delete_mapping(
        mapping.id,
        "admin@example.com"
      )

      conn =
        delete(conn, ~p"/api/academic-mentorship-mapping/#{mapping.id}", %{
          updated_by: "admin@example.com"
        })

      assert json_response(conn, 404)["error"] =~ "already deleted"
    end

    test "returns 404 for non-existent mapping", %{conn: conn} do
      conn =
        delete(conn, ~p"/api/academic-mentorship-mapping/999999", %{
          updated_by: "admin@example.com"
        })

      assert json_response(conn, 404)["error"] =~ "not found"
    end
  end
end
