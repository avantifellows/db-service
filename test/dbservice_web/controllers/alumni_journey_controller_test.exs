defmodule DbserviceWeb.AlumniJourneyControllerTest do
  use DbserviceWeb.ConnCase

  import Ecto.Query

  import Dbservice.UsersFixtures

  alias Dbservice.Alumnis
  alias Dbservice.Alumnis.Alumni
  alias Dbservice.Alumnis.AlumniJourney
  alias Dbservice.Repo

  setup %{conn: conn} do
    {_user, student} = student_fixture()

    # Inserted directly, like the alumni that existed before journey rows did:
    # it has answers but no history.
    alumni =
      Repo.insert!(%Alumni{
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

  defp journey_rows(alumni) do
    Repo.all(from(j in AlumniJourney, where: j.alumni_id == ^alumni.id, order_by: j.id))
  end

  test "the first follow-up keeps a copy of the answers as they were before it", %{
    conn: conn,
    alumni: alumni
  } do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"data" => %{"ug_status" => "Completed"}})
      )

    body = json_response(conn, 201)
    assert body["alumni_id"] == alumni.id
    assert body["reported_year"] == 2026
    assert body["actor_email"] == "caller@avantifellows.org"
    assert body["data"]["ug_status"] == "Completed"
    assert body["data"]["current_ctc"] == 600_000.0
    assert Map.has_key?(body["data"], "pg_status")
    refute Map.has_key?(body["data"], "student_id")
    assert Enum.sort(body["changed_fields"]) == ["contact_status", "ug_status"]

    assert [initial, call] = journey_rows(alumni)
    assert call.id == body["id"]
    assert initial.source == "initial"
    assert initial.actor_role == "system"
    assert initial.actor_email == nil
    assert initial.data["ug_status"] == "Pursuing"
    assert Enum.sort(initial.changed_fields) == ["current_ctc", "degree_ug", "ug_status"]
    assert Date.compare(initial.reported_on, call.reported_on) != :gt
  end

  test "an alumnus with no answers gets no empty initial row", %{conn: conn} do
    {_user, student} = student_fixture()
    alumni = Repo.insert!(%Alumni{student_id: student.id})

    post(conn, ~p"/api/alumni/#{alumni.id}/journey", follow_up(%{}))

    assert [%{source: "call"}] = journey_rows(alumni)
  end

  test "a correction can clear an answer, so an earlier version can be restored", %{
    conn: conn,
    alumni: alumni
  } do
    post(
      conn,
      ~p"/api/alumni/#{alumni.id}/journey",
      follow_up(%{"data" => %{"degree_pg" => "M.Tech"}})
    )

    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{
          "source" => "correction",
          "data" => %{"degree_pg" => nil, "degree_ug" => " "}
        })
      )

    body = json_response(conn, 201)
    assert Enum.sort(body["changed_fields"]) == ["degree_pg", "degree_ug"]
    assert body["data"]["degree_pg"] == nil

    updated = Alumnis.get_alumni(alumni.id)
    assert updated.degree_pg == nil
    assert updated.degree_ug == nil
  end

  test "POST /api/alumni records the answers a new alumnus starts with", %{conn: conn} do
    {_user, student} = student_fixture()

    conn = post(conn, ~p"/api/alumni", %{"student_id" => student.id, "ug_status" => "Pursuing"})
    created = json_response(conn, 201)

    assert [row] = journey_rows(%{id: created["id"]})
    assert row.source == "initial"
    assert row.actor_role == "api"
    assert row.changed_fields == ["ug_status"]
  end

  test "PATCH /api/alumni keeps the old answers and records the change", %{
    conn: conn,
    alumni: alumni
  } do
    conn = patch(conn, ~p"/api/alumni/#{alumni.id}", %{"ug_status" => "Completed"})
    assert json_response(conn, 200)["ug_status"] == "Completed"

    assert [initial, correction] = journey_rows(alumni)
    assert initial.data["ug_status"] == "Pursuing"
    assert correction.source == "correction"
    assert correction.actor_role == "api"
    assert correction.changed_fields == ["ug_status"]

    # Saving the same answers again adds no row.
    patch(conn, ~p"/api/alumni/#{alumni.id}", %{"ug_status" => "Completed"})
    assert length(journey_rows(alumni)) == 2
  end

  test "the alumni_addition import records its changes as bulk_upload", %{alumni: alumni} do
    {:ok, _alumni} =
      Alumnis.update_alumni(alumni, %{"ug_status" => "Completed"}, %{
        "source" => "bulk_upload",
        "actor_role" => "import"
      })

    assert [%{source: "initial"}, %{source: "bulk_upload", actor_role: "import"}] =
             journey_rows(alumni)
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

    assert Repo.aggregate(AlumniJourney, :count) == 3
  end

  test "a blank answer never erases a recorded one", %{conn: conn, alumni: alumni} do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"data" => %{"ug_status" => "   ", "degree_ug" => nil, "degree_pg" => ""}})
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

  test "the call outcome is applied to alumni.contact_status", %{conn: conn, alumni: alumni} do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"contact_status" => "Not reachable"})
      )

    assert json_response(conn, 201)["data"]["contact_status"] == "Not reachable"
    assert Alumnis.get_alumni(alumni.id).contact_status == "Not reachable"
  end

  test "rejects a call outcome that contradicts data.contact_status", %{
    conn: conn,
    alumni: alumni
  } do
    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{
          "contact_status" => "Reached",
          "data" => %{"contact_status" => "Not reachable"}
        })
      )

    assert %{"errors" => %{"message" => "contact_status and data.contact_status disagree"}} =
             json_response(conn, 422)

    assert Repo.aggregate(AlumniJourney, :count) == 0
  end

  test "a call logged after a later change can be back-dated", %{conn: conn, alumni: alumni} do
    # Tuesday: an import changes the alumnus, dated today.
    {:ok, _alumni} =
      Alumnis.update_alumni(alumni, %{"degree_ug" => "B.Sc"}, %{
        "source" => "bulk_upload",
        "actor_role" => "import"
      })

    # Wednesday: Monday's call is logged, dated before the import row.
    reported_on = Date.add(Date.utc_today(), -2)

    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{
          "reported_on" => Date.to_iso8601(reported_on),
          "data" => %{"ug_status" => "Dropped"}
        })
      )

    body = json_response(conn, 201)
    assert body["reported_on"] == Date.to_iso8601(reported_on)

    # Compared against what was on file when it was logged, i.e. after the import.
    assert Enum.sort(body["changed_fields"]) == ["contact_status", "ug_status"]
    assert body["data"]["degree_ug"] == "B.Sc"

    assert [%{source: "initial"}, %{source: "bulk_upload"}, %{source: "call"}] =
             journey_rows(alumni)
  end

  test "rejects a reported_on after tomorrow or before 2000, allows tomorrow", %{
    conn: conn,
    alumni: alumni
  } do
    for date <- [Date.add(Date.utc_today(), 2), ~D[2099-01-01], ~D[1999-12-31], ~D[0001-01-01]] do
      conn =
        post(
          conn,
          ~p"/api/alumni/#{alumni.id}/journey",
          follow_up(%{"reported_on" => Date.to_iso8601(date)})
        )

      assert %{"errors" => %{"reported_on" => [_]}} = json_response(conn, 422)
    end

    assert Repo.aggregate(AlumniJourney, :count) == 0

    tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

    assert post(
             conn,
             ~p"/api/alumni/#{alumni.id}/journey",
             follow_up(%{"reported_on" => tomorrow})
           )
           |> json_response(201)
  end

  test "a notes-only call still records a row", %{conn: conn, alumni: alumni} do
    post(conn, ~p"/api/alumni/#{alumni.id}/journey", follow_up(%{}))

    conn =
      post(
        conn,
        ~p"/api/alumni/#{alumni.id}/journey",
        follow_up(%{"notes" => "Wrong phone number"})
      )

    body = json_response(conn, 201)
    assert body["changed_fields"] == []
    assert body["notes"] == "Wrong phone number"
  end

  test "a save that changes nothing leaves no history, so the alumnus can still be deleted", %{
    conn: conn,
    alumni: alumni
  } do
    assert patch(conn, ~p"/api/alumni/#{alumni.id}", %{"ug_status" => "Pursuing"})
           |> json_response(200)

    assert patch(conn, ~p"/api/alumni/#{alumni.id}", %{}) |> json_response(200)

    assert journey_rows(alumni) == []
    assert delete(conn, ~p"/api/alumni/#{alumni.id}") |> response(204)
  end

  test "an alumnus with follow-up history cannot be deleted", %{conn: conn, alumni: alumni} do
    post(conn, ~p"/api/alumni/#{alumni.id}/journey", follow_up(%{}))

    conn = delete(conn, ~p"/api/alumni/#{alumni.id}")

    assert %{"errors" => %{"id" => ["has follow-up history and cannot be deleted"]}} =
             json_response(conn, 422)

    assert Alumnis.get_alumni(alumni.id)
  end

  test "an alumnus without history can still be deleted", %{conn: conn, alumni: alumni} do
    assert delete(conn, ~p"/api/alumni/#{alumni.id}") |> response(204)
  end
end
