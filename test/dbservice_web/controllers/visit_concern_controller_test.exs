defmodule DbserviceWeb.VisitConcernControllerTest do
  use DbserviceWeb.ConnCase

  alias Dbservice.Repo

  # SHA-256 of the two bytes `[]`, worked out with `printf '[]' | shasum -a 256`.
  @empty_fingerprint "4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"

  # SHA-256 of the hand-written UTF-8 JSON
  # [["principal_interaction","lab_access","Lab is locked — keys with clerk"],
  #  ["principal_interaction","additional_notes","Ask for a spare key"]]
  # (no spaces or newlines), worked out with `shasum -a 256`.
  @golden_fingerprint "681fb082f212f3590b44733326c196c1eaa1c0060221b091914282db5823e6c1"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/visit-concerns/pending-visits" do
    test "returns completed, non-deleted Visits in visit_date, id order", %{conn: conn} do
      later = insert_visit(%{visit_date: ~D[2026-10-12], school_code: "70705"})
      same_day_first = insert_visit(%{visit_date: ~D[2026-10-10], school_code: "70705"})
      same_day_second = insert_visit(%{visit_date: ~D[2026-10-10], school_code: "14042"})
      insert_visit(%{visit_date: ~D[2026-10-09], status: "in_progress", completed_at: nil})
      insert_visit(%{visit_date: ~D[2026-10-09], deleted_at: ~N[2026-10-11 05:00:00]})

      body =
        conn
        |> get(~p"/api/visit-concerns/pending-visits?prompt_version=v1")
        |> json_response(200)

      assert body["visits"] == [
               %{
                 "visit_id" => same_day_first,
                 "school_code" => "70705",
                 "visit_date" => "2026-10-10",
                 "fingerprint" => @empty_fingerprint,
                 "items" => []
               },
               %{
                 "visit_id" => same_day_second,
                 "school_code" => "14042",
                 "visit_date" => "2026-10-10",
                 "fingerprint" => @empty_fingerprint,
                 "items" => []
               },
               %{
                 "visit_id" => later,
                 "school_code" => "70705",
                 "visit_date" => "2026-10-12",
                 "fingerprint" => @empty_fingerprint,
                 "items" => []
               }
             ]

      assert body["next_cursor"] == nil
    end

    test "skips a Visit whose summary matches until the prompt version, fingerprint or force asks",
         %{conn: conn} do
      current = insert_visit(%{visit_date: ~D[2026-10-10]})
      stale = insert_visit(%{visit_date: ~D[2026-10-11]})
      insert_summary(current, @empty_fingerprint, "v1")
      insert_summary(stale, String.duplicate("0", 64), "v1")

      assert pending_ids(conn, "prompt_version=v1") == [stale]
      assert pending_ids(conn, "prompt_version=v2") == [current, stale]
      assert pending_ids(conn, "prompt_version=v1&force=true") == [current, stale]
      assert pending_ids(conn, "prompt_version=v1&force=false") == [stale]
    end

    test "extracts remarks per action type in action id, key order with additional_notes last",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "classroom_observation",
          data: %{
            "teacher_name" => "Indrani Khan",
            "params" => %{
              "teaching_methodology" => %{"score" => 3, "remarks" => "  Uses daily examples "},
              "board_work" => %{"score" => 2, "remarks" => "Board is cluttered"}
            },
            "observer_summary_improvements" => "Pace is too fast",
            "observer_summary_strengths" => "Good rapport with the class",
            "additional_notes" => "Class started ten minutes late"
          }
        },
        %{
          action_type: "principal_interaction",
          data: %{
            "additional_notes" => "Principal wants more mock tests",
            "questions" => %{
              "lab_access" => %{"answer" => "no", "remark" => "Lab keys are with the clerk"},
              "Attendance" => %{"answer" => "yes", "remark" => "Attendance dips on Saturdays"}
            }
          }
        },
        %{
          action_type: "af_team_interaction",
          data: %{"questions" => %{"support" => %{"remark" => "Needs a second PM visit"}}}
        },
        %{
          action_type: "group_student_discussion",
          data: %{"questions" => %{"doubts" => %{"remark" => "Students want doubt sessions"}}}
        },
        %{
          action_type: "school_staff_interaction",
          data: %{
            "questions" => %{"timetable" => %{"remark" => "Physics periods were cut"}},
            "additional_notes" => "Staff room is shared"
          }
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]

      assert items == [
               item("classroom_observation", "board_work", "Board is cluttered"),
               item("classroom_observation", "teaching_methodology", "Uses daily examples"),
               item(
                 "classroom_observation",
                 "observer_summary_strengths",
                 "Good rapport with the class"
               ),
               item("classroom_observation", "observer_summary_improvements", "Pace is too fast"),
               item(
                 "classroom_observation",
                 "additional_notes",
                 "Class started ten minutes late"
               ),
               item("principal_interaction", "Attendance", "Attendance dips on Saturdays"),
               item("principal_interaction", "lab_access", "Lab keys are with the clerk"),
               item(
                 "principal_interaction",
                 "additional_notes",
                 "Principal wants more mock tests"
               ),
               item("af_team_interaction", "support", "Needs a second PM visit"),
               item("group_student_discussion", "doubts", "Students want doubt sessions"),
               item("school_staff_interaction", "timetable", "Physics periods were cut"),
               item("school_staff_interaction", "additional_notes", "Staff room is shared")
             ]
    end

    test "unknown and not-yet-extracted action types contribute only additional_notes",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "lab_inspection",
          data: %{
            "questions" => %{"lab" => %{"remark" => "Not read for unknown types"}},
            "additional_notes" => "Microscopes are missing"
          }
        },
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => [%{"questions" => %{"q1" => %{"remark" => "Covered in a later slice"}}}],
            "additional_notes" => "Two teachers were on leave"
          }
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]

      assert items == [
               item("lab_inspection", "additional_notes", "Microscopes are missing"),
               item(
                 "individual_af_teacher_interaction",
                 "additional_notes",
                 "Two teachers were on leave"
               )
             ]
    end

    test "drops blank and non-string remarks and never reads checkbox or score fields",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "principal_interaction",
          data: %{
            "questions" => %{
              "empty" => %{"answer" => "yes", "remark" => ""},
              "spaces" => %{"answer" => "no", "remark" => "  \n\t "},
              "number" => %{"answer" => "no", "remark" => 4},
              "missing" => %{"answer" => "yes"},
              "kept" => %{"answer" => "yes", "remark" => "Wants weekly reports"}
            },
            "additional_notes" => "   "
          }
        },
        %{
          action_type: "classroom_observation",
          data: %{
            "params" => %{"pace" => %{"score" => 5, "remarks" => nil}},
            "observer_summary_strengths" => ["not", "a", "string"],
            "observer_summary_improvements" => " ",
            "additional_notes" => 7
          }
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]
      assert items == [item("principal_interaction", "kept", "Wants weekly reports")]
    end

    test "skips malformed action data without failing", %{conn: conn} do
      insert_visit(%{}, [
        %{action_type: "principal_interaction", data: "not a map"},
        %{action_type: "principal_interaction", data: ["a", "list"]},
        %{action_type: "principal_interaction", data: nil},
        %{action_type: "classroom_observation", data: %{"params" => ["a", "list"]}},
        %{action_type: "classroom_observation", data: %{"params" => %{"pace" => "fast"}}},
        %{action_type: "af_team_interaction", data: %{"questions" => "not a map"}},
        %{
          action_type: "school_staff_interaction",
          data: %{"questions" => %{"bad" => ["x"], "good" => %{"remark" => "Still read"}}}
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]
      assert items == [item("school_staff_interaction", "good", "Still read")]
    end

    test "reads pending and in-progress actions and ignores deleted ones", %{conn: conn} do
      insert_visit(%{}, [
        %{action_type: "x", status: "pending", data: %{"additional_notes" => "Pending note"}},
        %{action_type: "x", status: "in_progress", data: %{"additional_notes" => "Started note"}},
        %{
          action_type: "x",
          status: "pending",
          deleted_at: ~N[2026-10-11 05:00:00],
          data: %{"additional_notes" => "Deleted note"}
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]

      assert items == [
               item("x", "additional_notes", "Pending note"),
               item("x", "additional_notes", "Started note")
             ]
    end

    test "fingerprints the free text: pinned value, blind to checkboxes, sensitive to remarks",
         %{conn: conn} do
      visit_id =
        insert_visit(%{}, [
          %{
            action_type: "principal_interaction",
            data: %{
              "questions" => %{
                "lab_access" => %{
                  "answer" => "no",
                  "score" => 2,
                  "remark" => "Lab is locked — keys with clerk"
                }
              },
              "additional_notes" => "Ask for a spare key"
            }
          }
        ])

      assert [%{"fingerprint" => @golden_fingerprint}] =
               pending_visits(conn, "prompt_version=v1")["visits"]

      insert_summary(visit_id, @golden_fingerprint, "v1")

      set_action_data(visit_id, %{
        "questions" => %{
          "lab_access" => %{
            "answer" => "yes",
            "score" => 5,
            "remark" => "Lab is locked — keys with clerk"
          }
        },
        "additional_notes" => "Ask for a spare key"
      })

      assert pending_ids(conn, "prompt_version=v1") == []

      set_action_data(visit_id, %{
        "questions" => %{
          "lab_access" => %{"answer" => "yes", "score" => 5, "remark" => "Lab is open now"}
        },
        "additional_notes" => "Ask for a spare key"
      })

      assert [%{"visit_id" => ^visit_id, "fingerprint" => fingerprint}] =
               pending_visits(conn, "prompt_version=v1")["visits"]

      assert fingerprint =~ ~r/\A[0-9a-f]{64}\z/
      refute fingerprint == @golden_fingerprint
    end

    test "pages with limit and next_cursor, returning each pending Visit once", %{conn: conn} do
      a = insert_visit(%{visit_date: ~D[2026-10-01]})
      current = insert_visit(%{visit_date: ~D[2026-10-02]})
      b = insert_visit(%{visit_date: ~D[2026-10-03]})
      c = insert_visit(%{visit_date: ~D[2026-10-03]})
      d = insert_visit(%{visit_date: ~D[2026-10-05]})
      e = insert_visit(%{visit_date: ~D[2026-10-06]})
      insert_summary(current, @empty_fingerprint, "v1")

      page1 = pending_visits(conn, "prompt_version=v1&limit=2")
      assert Enum.map(page1["visits"], & &1["visit_id"]) == [a, b]
      assert page1["next_cursor"] == %{"after_visit_date" => "2026-10-03", "after_id" => b}

      # etl-next summarises the first page before asking for the next one.
      insert_summary(a, @empty_fingerprint, "v1")
      insert_summary(b, @empty_fingerprint, "v1")

      page2 = pending_visits(conn, "prompt_version=v1&limit=2&" <> cursor_query(page1))
      assert Enum.map(page2["visits"], & &1["visit_id"]) == [c, d]
      assert page2["next_cursor"] == %{"after_visit_date" => "2026-10-05", "after_id" => d}

      page3 = pending_visits(conn, "prompt_version=v1&limit=2&" <> cursor_query(page2))
      assert Enum.map(page3["visits"], & &1["visit_id"]) == [e]
      assert page3["next_cursor"] == nil

      full_page = pending_visits(conn, "prompt_version=v2&limit=6")
      assert Enum.map(full_page["visits"], & &1["visit_id"]) == [a, current, b, c, d, e]
      assert full_page["next_cursor"] == nil
    end

    test "keeps scanning past a long run of already-summarised Visits", %{conn: conn} do
      now = ~N[2026-10-20 06:00:00]

      visits =
        for _ <- 1..250 do
          %{
            school_code: "70705",
            pm_email: "pm@avantifellows.org",
            visit_date: ~D[2026-09-01],
            status: "completed",
            completed_at: now,
            inserted_at: now,
            updated_at: now
          }
        end

      {250, rows} = Repo.insert_all("lms_pm_school_visits", visits, returning: [:id])

      Repo.insert_all(
        "lms_visit_note_summaries",
        Enum.map(rows, fn %{id: id} ->
          %{
            visit_id: id,
            fingerprint: @empty_fingerprint,
            prompt_version: "v1",
            summarised_at: now
          }
        end)
      )

      pending = insert_visit(%{visit_date: ~D[2026-10-01]})

      assert %{"visits" => [%{"visit_id" => ^pending}], "next_cursor" => nil} =
               pending_visits(conn, "prompt_version=v1&limit=1")
    end

    test "visit_ids restricts the scan", %{conn: conn} do
      first = insert_visit(%{visit_date: ~D[2026-10-01]})
      insert_visit(%{visit_date: ~D[2026-10-02]})
      third = insert_visit(%{visit_date: ~D[2026-10-03]})
      insert_summary(third, @empty_fingerprint, "v1")

      assert pending_ids(conn, "prompt_version=v1&visit_ids=#{third}, #{first}") == [first]

      assert pending_ids(conn, "prompt_version=v1&force=true&visit_ids=#{third},#{first}") ==
               [first, third]
    end

    test "lists every record at each School on the page, with the latest resolution in IST",
         %{conn: conn} do
      visit_id = insert_visit(%{school_code: "70705", visit_date: ~D[2026-10-12]})
      insert_visit(%{school_code: "14042", visit_date: ~D[2026-10-13]})
      deleted_visit = insert_visit(%{school_code: "70705", deleted_at: ~N[2026-10-11 05:00:00]})

      open = insert_record("70705", "concern", "Labs stay locked", "open")
      insert_mention(open, visit_id)

      # Resolved, reopened, then resolved again at 00:30 IST on the 11th.
      boundary = insert_record("70705", "concern", "Fans do not work", "resolved")
      insert_event(boundary, "resolved", ~N[2026-10-05 10:00:00])
      insert_event(boundary, "reopened", ~N[2026-10-07 10:00:00])
      insert_event(boundary, "resolved", ~N[2026-10-10 19:00:00])

      # Resolved at 23:30 IST on the 10th; only mentioned by a deleted Visit (hidden).
      late_evening = insert_record("70705", "concern", "Library is shut", "resolved")
      insert_event(late_evening, "resolved", ~N[2026-10-10 18:00:00])
      insert_mention(late_evening, deleted_visit)

      highlight = insert_record("70705", "highlight", "Students ask many doubts", nil)
      insert_record("99999", "concern", "Another School's record", "open")

      body = pending_visits(conn, "prompt_version=v1")

      assert body["records_by_school"] == %{
               "70705" => [
                 record(open, "concern", "Labs stay locked", "open", nil),
                 record(boundary, "concern", "Fans do not work", "resolved", "2026-10-11"),
                 record(late_evening, "concern", "Library is shut", "resolved", "2026-10-10"),
                 record(highlight, "highlight", "Students ask many doubts", nil, nil)
               ],
               "14042" => []
             }
    end

    test "rejects a request without the bearer token" do
      assert build_conn()
             |> get("/api/visit-concerns/pending-visits?prompt_version=v1")
             |> response(401) == "Not Authorized"
    end

    test "rejects malformed query parameters with 400", %{conn: conn} do
      insert_visit(%{})

      for query <- [
            "",
            "prompt_version=",
            "prompt_version=%20%20",
            "prompt_version=" <> String.duplicate("v", 51),
            "prompt_version=v1&limit=0",
            "prompt_version=v1&limit=201",
            "prompt_version=v1&limit=ten",
            "prompt_version=v1&after_visit_date=2026-10-10",
            "prompt_version=v1&after_id=12",
            "prompt_version=v1&after_visit_date=10/10/2026&after_id=12",
            "prompt_version=v1&after_visit_date=2026-10-10&after_id=x",
            "prompt_version=v1&visit_ids=1,x",
            "prompt_version=v1&visit_ids=" <> Enum.join(1..201, ","),
            "prompt_version=v1&force=yes"
          ] do
        assert %{"error" => message} =
                 conn |> get("/api/visit-concerns/pending-visits?" <> query) |> json_response(400),
               "expected 400 for #{inspect(query)}"

        assert is_binary(message)
      end
    end

    test "accepts boundary values", %{conn: conn} do
      visit_id = insert_visit(%{})

      for query <- [
            "prompt_version=" <> String.duplicate("v", 50),
            "prompt_version=v1&limit=1",
            "prompt_version=v1&limit=200",
            "prompt_version=v1&visit_ids=" <> Enum.join(Enum.to_list(1..199) ++ [visit_id], ",")
          ] do
        assert [^visit_id] = pending_ids(conn, query), "expected 200 for #{inspect(query)}"
      end
    end
  end

  defp record(id, kind, text, status, latest_resolved_on) do
    %{
      "id" => id,
      "kind" => kind,
      "text" => text,
      "status" => status,
      "latest_resolved_on" => latest_resolved_on
    }
  end

  defp item(action_type, label, text),
    do: %{"action_type" => action_type, "label" => label, "text" => text}

  defp pending_visits(conn, query) do
    conn |> get("/api/visit-concerns/pending-visits?" <> query) |> json_response(200)
  end

  defp cursor_query(%{"next_cursor" => cursor}) do
    "after_visit_date=#{cursor["after_visit_date"]}&after_id=#{cursor["after_id"]}"
  end

  defp pending_ids(conn, query) do
    conn |> pending_visits(query) |> Map.fetch!("visits") |> Enum.map(& &1["visit_id"])
  end

  defp insert_record(school_code, kind, text, status) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO lms_visit_concerns (school_code, kind, text, status, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, '2026-10-01 06:00:00', '2026-10-01 06:00:00')
        RETURNING id
        """,
        [school_code, kind, text, status]
      ).rows

    id
  end

  defp insert_mention(concern_id, visit_id) do
    Repo.query!(
      """
      INSERT INTO lms_visit_concern_mentions (concern_id, visit_id, snippet)
      VALUES ($1, $2, 'Raised again in this Visit')
      """,
      [concern_id, visit_id]
    )
  end

  defp insert_event(concern_id, kind, inserted_at) do
    Repo.query!(
      """
      INSERT INTO lms_visit_concern_events (concern_id, kind, body, author_email, inserted_at)
      VALUES ($1, $2, 'Checked with the principal', 'pm@avantifellows.org', $3)
      """,
      [concern_id, kind, inserted_at]
    )
  end

  defp set_action_data(visit_id, data) do
    Repo.query!("UPDATE lms_pm_school_visit_actions SET data = $1 WHERE visit_id = $2", [
      data,
      visit_id
    ])
  end

  defp insert_summary(visit_id, fingerprint, prompt_version) do
    Repo.insert_all("lms_visit_note_summaries", [
      %{
        visit_id: visit_id,
        fingerprint: fingerprint,
        prompt_version: prompt_version,
        summarised_at: ~N[2026-10-20 07:00:00]
      }
    ])
  end

  # Inserts a Visit and its actions; returns the Visit id. Each action is a map
  # with `action_type` and `data`, plus optional `status` and `deleted_at`.
  defp insert_visit(attrs, actions \\ []) do
    now = ~N[2026-10-20 06:00:00]

    visit =
      Map.merge(
        %{
          school_code: "70705",
          pm_email: "pm@avantifellows.org",
          visit_date: ~D[2026-10-10],
          status: "completed",
          completed_at: now,
          deleted_at: nil,
          inserted_at: now,
          updated_at: now
        },
        attrs
      )

    {1, [%{id: visit_id}]} = Repo.insert_all("lms_pm_school_visits", [visit], returning: [:id])

    Enum.each(actions, &insert_action(visit_id, &1))
    visit_id
  end

  defp insert_action(visit_id, action) do
    now = ~N[2026-10-20 06:00:00]
    status = Map.get(action, :status, "completed")

    {started_at, ended_at} =
      case status do
        "pending" -> {nil, nil}
        "in_progress" -> {now, nil}
        "completed" -> {now, now}
      end

    {1, [%{id: action_id}]} =
      Repo.insert_all(
        "lms_pm_school_visit_actions",
        [
          %{
            visit_id: visit_id,
            action_type: action.action_type,
            data: action.data,
            status: status,
            started_at: started_at,
            ended_at: ended_at,
            deleted_at: Map.get(action, :deleted_at),
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    action_id
  end
end
