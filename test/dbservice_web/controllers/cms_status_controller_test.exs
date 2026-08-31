defmodule DbserviceWeb.CmsStatusControllerTest do
  @moduledoc """
  POST /api/cms-status must be idempotent: re-POSTing an existing name (as the
  gsheets-to-db sync does on every run) is a no-op success, not an unhandled 500
  on the unique index (issue #694).
  """
  use DbserviceWeb.ConnCase

  alias Dbservice.CmsStatuses
  alias Dbservice.Repo
  alias Dbservice.CmsStatuses.CmsStatus
  import Ecto.Query

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  defp name_count(name) do
    Repo.aggregate(from(c in CmsStatus, where: c.name == ^name), :count)
  end

  describe "create cms_status" do
    test "creates a new cms_status", %{conn: conn} do
      name = "archived-#{System.unique_integer([:positive])}"
      conn = post(conn, ~p"/api/cms-status", %{"name" => name})

      assert %{"id" => id, "name" => ^name} = json_response(conn, 201)
      assert is_integer(id)
    end

    test "re-POSTing an existing name is an idempotent no-op (issue #694)", %{conn: conn} do
      name = "live-#{System.unique_integer([:positive])}"
      {:ok, existing} = CmsStatuses.create_cms_status(%{"name" => name})

      conn = post(conn, ~p"/api/cms-status", %{"name" => name})

      # Returns the existing record with 200 (not 201) and does not duplicate it.
      assert %{"id" => id, "name" => ^name} = json_response(conn, 200)
      assert id == existing.id
      assert name_count(name) == 1
    end

    test "matches case-insensitively so a differing-case re-sync stays a no-op", %{conn: conn} do
      name = "draft-#{System.unique_integer([:positive])}"
      {:ok, existing} = CmsStatuses.create_cms_status(%{"name" => name})

      conn = post(conn, ~p"/api/cms-status", %{"name" => String.upcase(name)})

      assert %{"id" => id} = json_response(conn, 200)
      assert id == existing.id
      assert name_count(name) == 1
    end

    test "missing name returns a 422 changeset error, not a crash", %{conn: conn} do
      conn = post(conn, ~p"/api/cms-status", %{})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "create_cms_status/1 unique_constraint safety net" do
    test "a duplicate exact name returns {:error, changeset}, not a raised ConstraintError" do
      name = "safety-#{System.unique_integer([:positive])}"
      {:ok, _} = CmsStatuses.create_cms_status(%{"name" => name})

      assert {:error, %Ecto.Changeset{} = changeset} =
               CmsStatuses.create_cms_status(%{"name" => name})

      refute changeset.valid?
      assert {"has already been taken", _} = changeset.errors[:name]
    end
  end
end
