defmodule DbserviceWeb.VisitConcernControllerTest do
  use DbserviceWeb.ConnCase

  import Dbservice.VisitConcernsFixtures
  import ExUnit.CaptureLog
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

    test "unknown action types contribute only additional_notes", %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "lab_inspection",
          data: %{
            "questions" => %{"lab" => %{"remark" => "Not read for unknown types"}},
            "additional_notes" => "Microscopes are missing"
          }
        }
      ])

      assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]

      assert items == [item("lab_inspection", "additional_notes", "Microscopes are missing")]
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
            "prompt_version=v1&visit_ids=0",
            "prompt_version=v1&visit_ids=1,9223372036854775808",
            "prompt_version=v1&after_visit_date=2026-10-10&after_id=0",
            "prompt_version=v1&after_visit_date=2026-10-10&after_id=9223372036854775808",
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
            "prompt_version=v1&visit_ids=" <> Enum.join(Enum.to_list(1..199) ++ [visit_id], ","),
            "prompt_version=v1&visit_ids=#{visit_id},9223372036854775807",
            "prompt_version=v1&after_visit_date=2026-10-09&after_id=9223372036854775807"
          ] do
        assert [^visit_id] = pending_ids(conn, query), "expected 200 for #{inspect(query)}"
      end
    end
  end

  describe "PUT /api/visit-concerns/visit-summary/:visit_id" do
    test "creates records and mentions, records the summary and returns the School's records",
         %{conn: conn} do
      visit_id = insert_visit(%{school_code: "70705", visit_date: ~D[2026-10-12]})
      other_visit = insert_visit(%{school_code: "70705", visit_date: ~D[2026-10-01]})
      existing = insert_record("70705", "concern", "Labs stay locked", "open")
      insert_mention(existing, other_visit)
      insert_record("99999", "concern", "Another School's record", "open")

      body =
        conn
        |> put_summary(visit_id, %{
          "fingerprint" => @golden_fingerprint,
          "prompt_version" => "v1",
          "points" => [
            %{"existing_id" => existing, "kind" => "concern", "snippet" => " Lab still shut "},
            %{
              "new" => %{"kind" => "concern", "text" => "  Fans do not work "},
              "snippet" => "Fans broken in 9A"
            },
            %{
              "new" => %{"kind" => "highlight", "text" => "Students ask many doubts"},
              "snippet" => "Many doubts asked"
            }
          ]
        })
        |> json_response(200)

      assert [record_existing, %{"id" => fans} = record_fans, %{"id" => doubts} = record_doubts] =
               body["records"]

      assert record_existing == record(existing, "concern", "Labs stay locked", "open", nil)
      assert record_fans == record(fans, "concern", "Fans do not work", "open", nil)
      assert record_doubts == record(doubts, "highlight", "Students ask many doubts", nil, nil)
      assert existing < fans and fans < doubts

      assert mentions_of(visit_id) ==
               MapSet.new([
                 {existing, "Lab still shut"},
                 {fans, "Fans broken in 9A"},
                 {doubts, "Many doubts asked"}
               ])

      assert %{rows: [[@golden_fingerprint, "v1", %NaiveDateTime{}]]} =
               Repo.query!(
                 "SELECT fingerprint, prompt_version, summarised_at FROM lms_visit_note_summaries WHERE visit_id = $1",
                 [visit_id]
               )

      assert %{rows: [[2]]} =
               Repo.query!(
                 "SELECT count(*) FROM lms_visit_concerns WHERE inserted_at = updated_at AND id = ANY($1)",
                 [[fans, doubts]]
               )
    end

    test "a summarised Visit leaves the GET until its remarks change", %{conn: conn} do
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

      assert [%{"visit_id" => ^visit_id, "fingerprint" => fingerprint}] =
               pending_visits(conn, "prompt_version=v1")["visits"]

      conn
      |> put_summary(visit_id, summary_body(fingerprint, []))
      |> json_response(200)

      assert pending_ids(conn, "prompt_version=v1") == []
      assert pending_ids(conn, "prompt_version=v2") == [visit_id]

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
        "questions" => %{"lab_access" => %{"remark" => "Lab is open now"}},
        "additional_notes" => "Ask for a spare key"
      })

      assert pending_ids(conn, "prompt_version=v1") == [visit_id]
    end

    test "an identical re-PUT creates nothing new and only advances summarised_at",
         %{conn: conn} do
      visit_id = insert_visit(%{})
      existing = insert_record("70705", "concern", "Labs stay locked", "open")

      body =
        summary_body(@golden_fingerprint, [
          %{"existing_id" => existing, "kind" => "concern", "snippet" => "Lab still shut"},
          new_point("concern", "Fans do not work", "Fans broken in 9A"),
          new_point("highlight", "Students ask many doubts", "Many doubts asked")
        ])

      first = conn |> put_summary(visit_id, body) |> json_response(200)
      mentions = mentions_of(visit_id)
      counts = row_counts()

      Repo.query!(
        "UPDATE lms_visit_note_summaries SET summarised_at = '2026-01-01 00:00:00' WHERE visit_id = $1",
        [visit_id]
      )

      second = conn |> put_summary(visit_id, body) |> json_response(200)

      assert second == first
      assert mentions_of(visit_id) == mentions
      assert row_counts() == counts

      assert %{rows: [[summarised_at]]} =
               Repo.query!(
                 "SELECT summarised_at FROM lms_visit_note_summaries WHERE visit_id = $1",
                 [visit_id]
               )

      assert NaiveDateTime.compare(summarised_at, ~N[2026-01-01 00:00:00]) == :gt
    end

    test "a changed body replaces the Visit's mentions without changing dropped records' status",
         %{conn: conn} do
      visit_id = insert_visit(%{})
      other_visit = insert_visit(%{visit_date: ~D[2026-10-01]})
      open = insert_record("70705", "concern", "Labs stay locked", "open")
      resolved = insert_record("70705", "concern", "Fans do not work", "resolved")
      kept = insert_record("70705", "highlight", "Students ask many doubts", nil)
      insert_mention(open, other_visit)

      conn
      |> put_summary(
        visit_id,
        summary_body(@golden_fingerprint, [
          %{"existing_id" => open, "kind" => "concern", "snippet" => "Lab still shut"},
          %{"existing_id" => resolved, "kind" => "concern", "snippet" => "Fans broken"},
          %{"existing_id" => kept, "kind" => "highlight", "snippet" => "Many doubts"}
        ])
      )
      |> json_response(200)

      body =
        conn
        |> put_summary(
          visit_id,
          summary_body(@golden_fingerprint, [
            %{"existing_id" => kept, "kind" => "highlight", "snippet" => "Doubts in every class"}
          ])
        )
        |> json_response(200)

      assert mentions_of(visit_id) == MapSet.new([{kept, "Doubts in every class"}])
      assert mentions_of(other_visit) == MapSet.new([{open, "Raised again in this Visit"}])

      assert body["records"] == [
               record(open, "concern", "Labs stay locked", "open", nil),
               record(resolved, "concern", "Fans do not work", "resolved", nil),
               record(kept, "highlight", "Students ask many doubts", nil, nil)
             ]
    end

    test "duplicate points collapse to one mention that keeps the first snippet", %{conn: conn} do
      visit_id = insert_visit(%{})
      existing = insert_record("70705", "concern", "Labs stay locked", "open")

      body =
        conn
        |> put_summary(
          visit_id,
          summary_body(@golden_fingerprint, [
            %{"existing_id" => existing, "kind" => "concern", "snippet" => "First lab remark"},
            new_point("concern", "Fans do not work", "First fan remark"),
            %{"existing_id" => existing, "kind" => "concern", "snippet" => "Second lab remark"},
            new_point("concern", " Fans do not work", "Second fan remark")
          ])
        )
        |> json_response(200)

      assert [_existing, %{"id" => fans, "text" => "Fans do not work"}] = body["records"]

      assert mentions_of(visit_id) ==
               MapSet.new([{existing, "First lab remark"}, {fans, "First fan remark"}])
    end

    test "empty points clears the Visit's mentions and still records the summary",
         %{conn: conn} do
      visit_id = insert_visit(%{})
      existing = insert_record("70705", "concern", "Labs stay locked", "open")
      insert_mention(existing, visit_id)

      body =
        conn
        |> put_summary(visit_id, summary_body(@empty_fingerprint, []))
        |> json_response(200)

      assert body["records"] == [record(existing, "concern", "Labs stay locked", "open", nil)]
      assert mentions_of(visit_id) == MapSet.new()

      assert %{rows: [[@empty_fingerprint, "v1"]]} =
               Repo.query!(
                 "SELECT fingerprint, prompt_version FROM lms_visit_note_summaries WHERE visit_id = $1",
                 [visit_id]
               )
    end

    test "rejects a bad body with 400 and writes nothing", %{conn: conn} do
      visit_id = insert_visit(%{school_code: "70705"})
      own = insert_record("70705", "concern", "Labs stay locked", "open")
      highlight = insert_record("70705", "highlight", "Students ask many doubts", nil)
      foreign = insert_record("99999", "concern", "Another School's record", "open")
      insert_mention(own, visit_id)
      insert_summary(visit_id, @empty_fingerprint, "v0")
      valid_new = new_point("concern", "Fans do not work", "Fans broken")

      bad_points = [
        [valid_new, %{"existing_id" => foreign, "kind" => "concern", "snippet" => "Lab"}],
        [valid_new, %{"existing_id" => highlight, "kind" => "concern", "snippet" => "Doubts"}],
        [valid_new, %{"existing_id" => 999_999_999, "kind" => "concern", "snippet" => "Gone"}],
        [Map.put(valid_new, "existing_id", own)],
        [%{"kind" => "concern", "snippet" => "Neither"}],
        [%{"existing_id" => own, "snippet" => "No kind"}],
        [%{"existing_id" => 0, "kind" => "concern", "snippet" => "Zero id"}],
        [%{"existing_id" => 9_223_372_036_854_775_807, "kind" => "concern", "snippet" => "Max"}],
        [%{"existing_id" => 9_223_372_036_854_775_808, "kind" => "concern", "snippet" => "Big"}],
        [%{"existing_id" => "#{own}", "kind" => "concern", "snippet" => "String id"}],
        [new_point("issue", "Fans do not work", "Bad kind")],
        [%{"new" => "Fans do not work", "snippet" => "New is not a map"}],
        ["not a point"],
        [new_point("concern", String.duplicate("t", 501), "Too long")],
        [new_point("concern", "Fans do not work", String.duplicate("s", 301))],
        [new_point("concern", "   ", "Blank text")],
        [new_point("concern", "Fans do not work", "  ")],
        List.duplicate(valid_new, 101)
      ]

      bad_bodies =
        Enum.map(bad_points, &summary_body(@golden_fingerprint, &1)) ++
          [
            summary_body(String.upcase(@golden_fingerprint), [valid_new]),
            summary_body(String.slice(@golden_fingerprint, 0, 63), [valid_new]),
            Map.delete(summary_body(@golden_fingerprint, [valid_new]), "fingerprint"),
            Map.put(summary_body(@golden_fingerprint, [valid_new]), "prompt_version", " "),
            Map.put(
              summary_body(@golden_fingerprint, [valid_new]),
              "prompt_version",
              String.duplicate("v", 51)
            ),
            Map.delete(summary_body(@golden_fingerprint, []), "points"),
            Map.put(summary_body(@golden_fingerprint, []), "points", %{"0" => valid_new})
          ]

      counts = row_counts()

      for body <- bad_bodies do
        assert %{"error" => message} =
                 conn |> put_summary(visit_id, body) |> json_response(400),
               "expected 400 for #{inspect(body, limit: 5)}"

        assert is_binary(message)
        assert row_counts() == counts
      end

      assert mentions_of(visit_id) == MapSet.new([{own, "Raised again in this Visit"}])

      assert %{"error" => error} =
               conn
               |> put_summary(
                 visit_id,
                 summary_body(@golden_fingerprint, [
                   valid_new,
                   %{"existing_id" => foreign, "kind" => "concern", "snippet" => "Lab"}
                 ])
               )
               |> json_response(400)

      assert error =~ "#{foreign}"

      for path_id <- ["abc", "0", "-1", "9223372036854775808"] do
        assert conn
               |> put(
                 "/api/visit-concerns/visit-summary/#{path_id}",
                 summary_body(@golden_fingerprint, [])
               )
               |> json_response(400) == %{"error" => "visit_id must be a positive integer"}
      end

      assert row_counts() == counts
    end

    test "a malformed body gets a JSON 400, writes nothing and is never logged",
         %{conn: conn} do
      visit_id = insert_visit(%{})
      counts = row_counts()

      log =
        capture_log(fn ->
          assert {400, _headers, body} =
                   assert_error_sent(400, fn ->
                     conn
                     |> put_req_header("content-type", "application/json")
                     |> put(
                       "/api/visit-concerns/visit-summary/#{visit_id}",
                       ~s({"points": [{"new": {"kind": "concern", "text": "QAMARK-TEXT)
                     )
                   end)

          assert Jason.decode!(body) == %{"error" => "malformed request body"}
        end)

      assert log =~ "Bad Request: malformed request body"
      refute log =~ "QAMARK"
      assert row_counts() == counts
    end

    test "the request log filters record text and snippets but keeps the rest" do
      params =
        @golden_fingerprint
        |> summary_body([new_point("concern", "QAMARK-TEXT", "QAMARK-SNIP"), concern_point(7)])
        |> Phoenix.Logger.filter_values()

      refute inspect(params) =~ "QAMARK"
      refute inspect(params) =~ "Lab still shut"

      assert params["points"] == [
               %{
                 "new" => %{"kind" => "concern", "text" => "[FILTERED]"},
                 "snippet" => "[FILTERED]"
               },
               %{"existing_id" => 7, "kind" => "concern", "snippet" => "[FILTERED]"}
             ]
    end

    test "accepts boundary lengths and stores trimmed values", %{conn: conn} do
      visit_id = insert_visit(%{})
      text = String.duplicate("t", 500)
      snippet = String.duplicate("s", 300)

      body =
        conn
        |> put_summary(
          visit_id,
          %{
            "fingerprint" => @golden_fingerprint,
            "prompt_version" => " " <> String.duplicate("v", 50) <> " ",
            "points" => List.duplicate(new_point("concern", " #{text} ", " #{snippet} "), 100)
          }
        )
        |> json_response(200)

      assert [%{"id" => id, "text" => ^text}] = body["records"]
      assert mentions_of(visit_id) == MapSet.new([{id, snippet}])
    end

    test "returns 404 for a missing, soft-deleted or in-progress Visit", %{conn: conn} do
      deleted = insert_visit(%{deleted_at: ~N[2026-10-11 05:00:00]})
      in_progress = insert_visit(%{status: "in_progress", completed_at: nil})
      counts = row_counts()

      for visit_id <- [deleted, in_progress, in_progress + 1_000_000, 9_223_372_036_854_775_807] do
        assert conn
               |> put_summary(
                 visit_id,
                 summary_body(@golden_fingerprint, [
                   new_point("concern", "Fans do not work", "Fans broken")
                 ])
               )
               |> json_response(404) == %{"error" => "Visit not found or not completed"}
      end

      assert row_counts() == counts
    end

    test "rejects a request without the bearer token" do
      visit_id = insert_visit(%{})

      assert build_conn()
             |> put_summary(visit_id, summary_body(@golden_fingerprint, []))
             |> response(401) == "Not Authorized"

      assert row_counts() == %{
               concerns: 0,
               mentions: 0,
               events: 0,
               summaries: 0
             }
    end
  end

  describe "PUT visit-summary auto-reopen" do
    test "a Visit dated the day after the latest resolution reopens the Concern",
         %{conn: conn} do
      visit_id = insert_visit(%{visit_date: ~D[2026-10-12]})
      concern = insert_record("70705", "concern", "Labs stay locked", "resolved")
      # 2026-10-11 16:00 IST.
      insert_event(concern, "resolved", ~N[2026-10-11 10:30:00])

      body =
        conn
        |> put_summary(visit_id, summary_body(@golden_fingerprint, [concern_point(concern)]))
        |> json_response(200)

      assert body["records"] == [
               record(concern, "concern", "Labs stay locked", "open", "2026-10-11")
             ]

      assert [["auto_reopened", nil, nil, ^visit_id, inserted_at]] = events_after_seed(concern)
      assert [["open", ^inserted_at]] = concern_row(concern)
      assert NaiveDateTime.compare(inserted_at, ~N[2026-10-20 00:00:00]) == :gt
    end

    test "a Visit on the resolution's IST day or earlier leaves the Concern resolved",
         %{conn: conn} do
      same_day = insert_visit(%{visit_date: ~D[2026-10-11]})
      earlier = insert_visit(%{visit_date: ~D[2026-10-09]})
      concern = insert_record("70705", "concern", "Labs stay locked", "resolved")
      # 2026-10-11 16:00 IST.
      insert_event(concern, "resolved", ~N[2026-10-11 10:30:00])

      for visit_id <- [same_day, earlier] do
        body =
          conn
          |> put_summary(visit_id, summary_body(@golden_fingerprint, [concern_point(concern)]))
          |> json_response(200)

        assert body["records"] == [
                 record(concern, "concern", "Labs stay locked", "resolved", "2026-10-11")
               ]
      end

      assert events_after_seed(concern) == []
      assert concern_row(concern) == [["resolved", ~N[2026-10-01 06:00:00]]]
    end

    test "compares the Visit date with the resolution's IST date, not its UTC date",
         %{conn: conn} do
      after_midnight = insert_record("70705", "concern", "Labs stay locked", "resolved")
      before_midnight = insert_record("70705", "concern", "Fans do not work", "resolved")
      # 00:30 IST on the 11th.
      insert_event(after_midnight, "resolved", ~N[2026-10-10 19:00:00])
      # 23:30 IST on the 10th.
      insert_event(before_midnight, "resolved", ~N[2026-10-10 18:00:00])
      visit_id = insert_visit(%{visit_date: ~D[2026-10-11]})

      body =
        conn
        |> put_summary(
          visit_id,
          summary_body(@golden_fingerprint, [
            concern_point(after_midnight),
            concern_point(before_midnight)
          ])
        )
        |> json_response(200)

      assert body["records"] == [
               record(after_midnight, "concern", "Labs stay locked", "resolved", "2026-10-11"),
               record(before_midnight, "concern", "Fans do not work", "open", "2026-10-10")
             ]

      assert events_after_seed(after_midnight) == []
      assert [["auto_reopened", nil, nil, ^visit_id, _]] = events_after_seed(before_midnight)
    end

    test "only the latest of several resolutions counts", %{conn: conn} do
      reopens = insert_record("70705", "concern", "Labs stay locked", "resolved")
      insert_event(reopens, "resolved", ~N[2026-10-12 06:00:00])
      insert_event(reopens, "reopened", ~N[2026-10-13 06:00:00])
      insert_event(reopens, "comment", ~N[2026-10-16 06:00:00])
      insert_event(reopens, "resolved", ~N[2026-10-14 06:00:00])

      stays = insert_record("70705", "concern", "Fans do not work", "resolved")
      insert_event(stays, "resolved", ~N[2026-10-02 06:00:00])
      insert_event(stays, "reopened", ~N[2026-10-03 06:00:00])
      insert_event(stays, "resolved", ~N[2026-10-15 06:00:00])

      visit_id = insert_visit(%{visit_date: ~D[2026-10-15]})

      body =
        conn
        |> put_summary(
          visit_id,
          summary_body(@golden_fingerprint, [concern_point(reopens), concern_point(stays)])
        )
        |> json_response(200)

      assert body["records"] == [
               record(reopens, "concern", "Labs stay locked", "open", "2026-10-14"),
               record(stays, "concern", "Fans do not work", "resolved", "2026-10-15")
             ]

      assert [["auto_reopened", nil, nil, ^visit_id, _]] = events_after_seed(reopens)
      assert events_after_seed(stays) == []
    end

    test "a resolved Concern with no resolved event stays resolved", %{conn: conn} do
      visit_id = insert_visit(%{visit_date: ~D[2026-10-15]})
      concern = insert_record("70705", "concern", "Labs stay locked", "resolved")
      insert_event(concern, "comment", ~N[2026-10-02 06:00:00])

      body =
        conn
        |> put_summary(visit_id, summary_body(@golden_fingerprint, [concern_point(concern)]))
        |> json_response(200)

      assert body["records"] == [record(concern, "concern", "Labs stay locked", "resolved", nil)]
      assert events_after_seed(concern) == []
      assert concern_row(concern) == [["resolved", ~N[2026-10-01 06:00:00]]]
    end

    test "an open Concern gets no event and a Highlight is never touched", %{conn: conn} do
      visit_id = insert_visit(%{visit_date: ~D[2026-10-15]})
      open = insert_record("70705", "concern", "Labs stay locked", "open")
      insert_event(open, "resolved", ~N[2026-10-02 06:00:00])
      insert_event(open, "reopened", ~N[2026-10-03 06:00:00])
      highlight = insert_record("70705", "highlight", "Students ask many doubts", nil)

      body =
        conn
        |> put_summary(
          visit_id,
          summary_body(@golden_fingerprint, [
            concern_point(open),
            %{"existing_id" => highlight, "kind" => "highlight", "snippet" => "Many doubts"}
          ])
        )
        |> json_response(200)

      assert body["records"] == [
               record(open, "concern", "Labs stay locked", "open", "2026-10-02"),
               record(highlight, "highlight", "Students ask many doubts", nil, nil)
             ]

      assert events_after_seed(open) == []
      assert concern_row(open) == [["open", ~N[2026-10-01 06:00:00]]]
      assert concern_row(highlight) == [[nil, ~N[2026-10-01 06:00:00]]]
    end

    test "re-PUTs never add a second event or undo the reopen", %{conn: conn} do
      visit_id = insert_visit(%{visit_date: ~D[2026-10-12]})
      concern = insert_record("70705", "concern", "Labs stay locked", "resolved")
      highlight = insert_record("70705", "highlight", "Students ask many doubts", nil)
      insert_event(concern, "resolved", ~N[2026-10-11 10:30:00])

      highlight_point = %{
        "existing_id" => highlight,
        "kind" => "highlight",
        "snippet" => "Doubts"
      }

      conn
      |> put_summary(visit_id, summary_body(@golden_fingerprint, [concern_point(concern)]))
      |> json_response(200)

      assert [["auto_reopened", nil, nil, ^visit_id, reopened_at]] = events_after_seed(concern)

      conn
      |> put_summary(visit_id, summary_body(@golden_fingerprint, [concern_point(concern)]))
      |> json_response(200)

      assert [["auto_reopened", nil, nil, ^visit_id, ^reopened_at]] = events_after_seed(concern)

      body =
        conn
        |> put_summary(visit_id, summary_body(@golden_fingerprint, [highlight_point]))
        |> json_response(200)

      assert [%{"id" => ^concern, "status" => "open"}, _highlight] = body["records"]
      assert [["open", ^reopened_at]] = concern_row(concern)
      assert [["auto_reopened", nil, nil, ^visit_id, ^reopened_at]] = events_after_seed(concern)
      assert mentions_of(visit_id) == MapSet.new([{highlight, "Doubts"}])
    end
  end

  describe "PUT visit-summary under concurrency" do
    # Runs outside the sandbox so three real connections contend for one Concern
    # row. The af_lms-style resolver holds the Concern FOR UPDATE until both PUTs
    # are waiting on it, then resolves it. Before the PUT locked its Concerns up
    # front, both PUTs took the mention FK's KEY SHARE on the row and then each
    # waited for the other's to get FOR UPDATE: a deadlock (40P01) and a 500.
    test "two Visits mentioning one locked Concern wait their turn and reopen after the resolution",
         %{conn: conn} do
      authorization = conn |> get_req_header("authorization") |> List.first()

      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
        school_code = "lock-#{System.unique_integer([:positive])}"
        concern = insert_record(school_code, "concern", "Labs stay locked", "open")
        # Both Visits are dated after any IST date the resolution can fall on.
        visit_ids =
          for days <- [2, 3],
              do:
                insert_visit(%{
                  school_code: school_code,
                  visit_date: Date.utc_today() |> Date.add(days)
                })

        try do
          parent = self()
          resolver = Task.async(fn -> resolve_while_locked(concern, parent) end)
          assert_receive :locked, 5_000

          puts =
            for visit_id <- visit_ids do
              Task.async(fn ->
                try do
                  Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
                    build_conn()
                    |> put_req_header("authorization", authorization)
                    |> put_req_header("accept", "application/json")
                    |> put_summary(
                      visit_id,
                      summary_body(@golden_fingerprint, [concern_point(concern)])
                    )
                    |> Map.fetch!(:status)
                  end)
                rescue
                  # A deadlock surfaces here; keep it as a value so cleanup still runs.
                  error -> {:raised, Exception.message(error)}
                end
              end)
            end

          await_lock_waiters(2)
          # The resolution commits more than a second after both PUTs started.
          Process.sleep(1_100)
          send(resolver.pid, :resolve)
          assert {:ok, resolved_at} = Task.await(resolver, 10_000)

          assert Enum.map(puts, &Task.await(&1, 15_000)) == [200, 200]

          # The first PUT to get the lock reopens; the second sees it open.
          assert [
                   ["resolved", nil, ^resolved_at],
                   ["auto_reopened", reopened_by, reopened_at]
                 ] =
                   Repo.query!(
                     """
                     SELECT kind, visit_id, inserted_at FROM lms_visit_concern_events
                     WHERE concern_id = $1 ORDER BY id
                     """,
                     [concern]
                   ).rows

          assert reopened_by in visit_ids
          assert NaiveDateTime.compare(reopened_at, resolved_at) in [:gt, :eq]
          assert concern_row(concern) == [["open", reopened_at]]

          assert Enum.map(visit_ids, &mentions_of/1) ==
                   List.duplicate(MapSet.new([{concern, "Lab still shut"}]), 2)
        after
          delete_unboxed_school(school_code, visit_ids)
        end
      end)
    end
  end

  # Holds `concern_id` FOR UPDATE, tells `parent` and, on `:resolve`, resolves it
  # with a `resolved` event at the current time and commits.
  defp resolve_while_locked(concern_id, parent) do
    Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
      Repo.transaction(fn ->
        Repo.query!("SELECT id FROM lms_visit_concerns WHERE id = $1 FOR UPDATE", [concern_id])
        send(parent, :locked)

        receive do
          :resolve ->
            resolved_at = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

            Repo.query!(
              "UPDATE lms_visit_concerns SET status = 'resolved', updated_at = $2 WHERE id = $1",
              [concern_id, resolved_at]
            )

            insert_event(concern_id, "resolved", resolved_at)
            resolved_at
        after
          10_000 -> Repo.rollback(:timeout)
        end
      end)
    end)
  end

  defp await_lock_waiters(count, attempts \\ 200) do
    %{rows: [[waiting]]} =
      Repo.query!("""
      SELECT count(*) FROM pg_stat_activity
      WHERE datname = current_database() AND wait_event_type = 'Lock'
        AND query LIKE '%lms_visit_concern%'
      """)

    cond do
      waiting >= count ->
        :ok

      attempts == 0 ->
        flunk("expected #{count} PUTs waiting on the Concern lock, saw #{waiting}")

      true ->
        Process.sleep(25)
        await_lock_waiters(count, attempts - 1)
    end
  end

  # Unboxed rows are committed, so remove them; events are append-only, so their
  # trigger is bypassed for this cleanup only.
  defp delete_unboxed_school(school_code, visit_ids) do
    Repo.transaction(fn ->
      Repo.query!("SET LOCAL session_replication_role = replica")

      Repo.query!(
        """
        DELETE FROM lms_visit_concern_events
        WHERE concern_id IN (SELECT id FROM lms_visit_concerns WHERE school_code = $1)
        """,
        [school_code]
      )

      Repo.query!("DELETE FROM lms_visit_concern_mentions WHERE visit_id = ANY($1)", [visit_ids])
      Repo.query!("DELETE FROM lms_visit_note_summaries WHERE visit_id = ANY($1)", [visit_ids])
      Repo.query!("DELETE FROM lms_visit_concerns WHERE school_code = $1", [school_code])
      Repo.query!("DELETE FROM lms_pm_school_visit_actions WHERE visit_id = ANY($1)", [visit_ids])
      Repo.query!("DELETE FROM lms_pm_school_visits WHERE id = ANY($1)", [visit_ids])
    end)
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

  defp cursor_query(%{"next_cursor" => cursor}) do
    "after_visit_date=#{cursor["after_visit_date"]}&after_id=#{cursor["after_id"]}"
  end

  defp put_summary(conn, visit_id, body) do
    put(conn, "/api/visit-concerns/visit-summary/#{visit_id}", body)
  end

  defp summary_body(fingerprint, points),
    do: %{"fingerprint" => fingerprint, "prompt_version" => "v1", "points" => points}

  defp new_point(kind, text, snippet),
    do: %{"new" => %{"kind" => kind, "text" => text}, "snippet" => snippet}

  defp row_counts do
    for {key, table} <- [
          concerns: "lms_visit_concerns",
          mentions: "lms_visit_concern_mentions",
          events: "lms_visit_concern_events",
          summaries: "lms_visit_note_summaries"
        ],
        into: %{} do
      %{rows: [[count]]} = Repo.query!("SELECT count(*) FROM #{table}")
      {key, count}
    end
  end

  defp mentions_of(visit_id) do
    Repo.query!(
      "SELECT concern_id, snippet FROM lms_visit_concern_mentions WHERE visit_id = $1",
      [visit_id]
    ).rows
    |> MapSet.new(fn [concern_id, snippet] -> {concern_id, snippet} end)
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

  defp concern_point(concern_id),
    do: %{"existing_id" => concern_id, "kind" => "concern", "snippet" => "Lab still shut"}

  # Events newer than any seeded one, oldest first.
  defp events_after_seed(concern_id) do
    Repo.query!(
      """
      SELECT kind, body, author_email, visit_id, inserted_at FROM lms_visit_concern_events
      WHERE concern_id = $1 AND inserted_at > '2026-10-20 00:00:00'
      ORDER BY inserted_at, id
      """,
      [concern_id]
    ).rows
  end

  defp concern_row(concern_id) do
    Repo.query!("SELECT status, updated_at FROM lms_visit_concerns WHERE id = $1", [concern_id]).rows
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
end
