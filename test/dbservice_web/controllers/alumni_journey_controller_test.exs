defmodule DbserviceWeb.AlumniJourneyControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.UsersFixtures

  alias Dbservice.Alumnis
  alias Dbservice.Alumnis.AlumniJourney
  alias Dbservice.Repo

  setup %{conn: conn} do
    {_user, student} = student_fixture()

    {:ok, alumni} =
      Alumnis.create_alumni(%{
        student_id: student.id,
        ug_status: "Pursuing",
        degree_ug: "B.Tech",
        current_ctc: 600_000.0
      })

    {:ok, conn: put_req_header(conn, "accept", "application/json"), alumni: alumni}
  end

  defp follow_up(attrs) do
    Map.merge(
      %{
        "reported_on" => "2026-11-20",
        "source" => "call",
        "contact_status" => "Reached",
        "actor_email" => "caller@avantifellows.org",
        "actor_role" => "alumni_manager"
      },
      attrs
    )
  end

  test "first row snapshots every answer and marks recorded ones as changed", %{
    conn: conn,
    alumni: alumni
  } do
    conn =
      post(conn, ~p"/api/alumni/#{alumni.id}/journey", follow_up(%{"source" => "initial"}))

    body = json_response(conn, 201)

    assert body["alumni_id"] == alumni.id
    assert body["reported_year"] == 2026
    assert body["source"] == "initial"
    assert body["actor_email"] == "caller@avantifellows.org"
    assert body["data"]["ug_status"] == "Pursuing"
    assert body["data"]["current_ctc"] == 600_000.0
    assert Map.has_key?(body["data"], "pg_status")
    refute Map.has_key?(body["data"], "student_id")
    assert Enum.sort(body["changed_fields"]) == ["current_ctc", "degree_ug", "ug_status"]
  end

  test "applies answers to alumni and records only what changed since the last row", %{
    conn: conn,
    alumni: alumni
  } do
    post(conn, ~p"/api/alumni/#{alumni.id}/journey", follow_up(%{"reported_on" => "2025-11-01"}))

    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{
          "data" => %{
            "ug_status" => "Completed",
            "degree_ug" => "B.Tech",
            "employment_status" => "Employed"
          }
        })
      )

    body = json_response(conn, 201)
    assert Enum.sort(body["changed_fields"]) == ["employment_status", "ug_status"]
    assert body["data"]["ug_status"] == "Completed"

    updated = Alumnis.get_alumni(alumni.id)
    assert updated.ug_status == "Completed"
    assert updated.employment_status == "Employed"

    assert Repo.aggregate(AlumniJourney, :count) == 2
  end

  test "a blank answer never erases a recorded one", %{conn: conn, alumni: alumni} do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"data" => %{"ug_status" => "", "degree_ug" => nil}})
      )

    body = json_response(conn, 201)
    assert body["data"]["ug_status"] == "Pursuing"
    assert body["data"]["degree_ug"] == "B.Tech"
    assert Alumnis.get_alumni(alumni.id).ug_status == "Pursuing"
  end

  test "rejects keys that are not alumni answers, including student_id", %{
    conn: conn,
    alumni: alumni
  } do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"data" => %{"ug_stauts" => "Completed", "student_id" => 1}})
      )

    assert %{"errors" => %{"message" => detail}} = json_response(conn, 422)
    assert detail =~ "student_id"
    assert detail =~ "ug_stauts"
    assert Repo.aggregate(AlumniJourney, :count) == 0
  end

  test "an invalid follow-up leaves alumni untouched", %{conn: conn, alumni: alumni} do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"source" => "whatsapp", "data" => %{"ug_status" => "Completed"}})
      )

    assert %{"errors" => %{"source" => _}} = json_response(conn, 422)
    assert Alumnis.get_alumni(alumni.id).ug_status == "Pursuing"
    assert Repo.aggregate(AlumniJourney, :count) == 0
  end

  test "requires reported_on and actor_email", %{conn: conn, alumni: alumni} do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"reported_on" => nil, "actor_email" => nil})
      )

    assert %{"errors" => errors} = json_response(conn, 422)
    assert Map.has_key?(errors, "reported_on")
    assert Map.has_key?(errors, "actor_email")
  end

  test "404s an unknown alumni", %{conn: conn} do
    conn = post(conn, ~p"/api/alumni/0/journey", follow_up(%{}))
    assert json_response(conn, 404)
  end
end
