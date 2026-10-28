defmodule DbserviceWeb.VisitConcernPeopleExtractionTest do
  @moduledoc """
  Per-teacher and per-student-entry Visit Concern extraction through
  GET /api/visit-concerns/pending-visits. Labels come from positions, keys and
  class context (grade and subject), never from a teacher's or a Student's name.
  """
  use DbserviceWeb.ConnCase

  import Dbservice.VisitConcernsFixtures
  alias Dbservice.Repo

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "individual_af_teacher_interaction" do
    test "labels remarks by teacher position then key, with additional_notes last",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "additional_notes" => "Both teachers asked for lab time",
            "teachers" => [
              %{
                "id" => 41,
                "name" => "Indrani Khan",
                "attendance" => "present",
                "questions" => %{
                  "syllabus" => %{"answer" => "no", "remark" => "Behind by two chapters"},
                  "Doubts" => %{"answer" => "yes", "remark" => "  Runs doubt hour on Fridays "}
                }
              },
              %{
                "id" => 42,
                "name" => "Ravi Sharma",
                "attendance" => "present",
                "questions" => %{
                  "syllabus" => %{"answer" => "yes", "remark" => "On track"}
                }
              }
            ]
          }
        }
      ])

      assert items(conn) == [
               item(
                 "individual_af_teacher_interaction",
                 "Teacher 1: Doubts",
                 "Runs doubt hour on Fridays"
               ),
               item(
                 "individual_af_teacher_interaction",
                 "Teacher 1: syllabus",
                 "Behind by two chapters"
               ),
               item("individual_af_teacher_interaction", "Teacher 2: syllabus", "On track"),
               item(
                 "individual_af_teacher_interaction",
                 "additional_notes",
                 "Both teachers asked for lab time"
               )
             ]
    end
  end

  describe "individual_student_discussion" do
    test "labels remarks by entry position, with the grade only when it is an integer",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_student_discussion",
          data: %{
            "entries" => [
              %{
                "grade" => 11,
                "students" => [%{"id" => 9001, "name" => "Asha Verma"}],
                "questions" => %{
                  "study_hours" => %{"answer" => "yes", "remark" => "Studies 3 hours daily"},
                  "concerns" => %{"remark" => "Finds organic chemistry hard"}
                }
              },
              %{
                "students" => [%{"id" => 9002, "name" => "Kabir Singh"}],
                "questions" => %{"concerns" => %{"remark" => "Misses the school bus"}}
              },
              %{
                "grade" => "12",
                "questions" => %{"concerns" => %{"remark" => "Wants more mock tests"}}
              },
              %{
                "grade" => 12.0,
                "questions" => %{"concerns" => %{"remark" => "Needs a quiet place to study"}}
              },
              %{
                "grade" => 12,
                "students" => [
                  %{"id" => 9003, "name" => "Meera Iyer"},
                  %{"id" => 9004, "name" => "Rohan Das"}
                ],
                "questions" => %{"concerns" => %{"remark" => "Both skip weekend tests"}}
              }
            ],
            "additional_notes" => "Spoke to five groups"
          }
        }
      ])

      assert items(conn) == [
               item(
                 "individual_student_discussion",
                 "Student entry 1 (grade 11): concerns",
                 "Finds organic chemistry hard"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 1 (grade 11): study_hours",
                 "Studies 3 hours daily"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 2: concerns",
                 "Misses the school bus"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 3: concerns",
                 "Wants more mock tests"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 4: concerns",
                 "Needs a quiet place to study"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 5 (grade 12): concerns",
                 "Both skip weekend tests"
               ),
               item("individual_student_discussion", "additional_notes", "Spoke to five groups")
             ]
    end
  end

  describe "labels and malformed data" do
    test "never put a teacher's or a Student's name in a label", %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => [
              %{
                "name" => "Indrani Khan",
                "questions" => %{"Indrani Khan" => %{"remark" => "Keyed by a name"}}
              }
            ]
          }
        },
        %{
          action_type: "individual_student_discussion",
          data: %{
            "entries" => [
              %{
                "grade" => 11,
                "name" => "Asha Verma",
                "students" => [%{"name" => "Kabir Singh"}],
                "questions" => %{"concerns" => %{"remark" => "Asha Verma needs a tutor"}}
              }
            ]
          }
        }
      ])

      labels = Enum.map(items(conn), & &1["label"])

      # The question key is a stable key, so it is kept; the `name` fields are not.
      assert labels == ["Teacher 1: Indrani Khan", "Student entry 1 (grade 11): concerns"]
      refute Enum.any?(labels, &(&1 =~ "Asha Verma" or &1 =~ "Kabir Singh"))
    end

    test "an invalid element still uses up its position", %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => [
              "not a map",
              %{
                "name" => "Ravi Sharma",
                "questions" => %{"syllabus" => %{"remark" => "On track"}}
              },
              %{"name" => "No questions"},
              %{"questions" => "not a map"},
              %{"questions" => %{"pace" => %{"remark" => "Rushes the last chapter"}}}
            ]
          }
        },
        %{
          action_type: "individual_student_discussion",
          data: %{
            "entries" => [
              nil,
              ["a", "list"],
              %{"grade" => 12, "questions" => %{"bad" => "x", "fees" => %{"remark" => "Fee due"}}}
            ]
          }
        }
      ])

      assert items(conn) == [
               item("individual_af_teacher_interaction", "Teacher 2: syllabus", "On track"),
               item(
                 "individual_af_teacher_interaction",
                 "Teacher 5: pace",
                 "Rushes the last chapter"
               ),
               item(
                 "individual_student_discussion",
                 "Student entry 3 (grade 12): fees",
                 "Fee due"
               )
             ]
    end

    test "a non-list teachers or entries contributes nothing but keeps additional_notes",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => %{"0" => %{"questions" => %{"q" => %{"remark" => "Not a list"}}}},
            "additional_notes" => "Teacher notes kept"
          }
        },
        %{
          action_type: "individual_student_discussion",
          data: %{"entries" => "not a list", "additional_notes" => "Entry notes kept"}
        },
        %{
          action_type: "individual_student_discussion",
          data: %{"entries" => nil, "additional_notes" => "Nil entries kept"}
        }
      ])

      assert items(conn) == [
               item(
                 "individual_af_teacher_interaction",
                 "additional_notes",
                 "Teacher notes kept"
               ),
               item("individual_student_discussion", "additional_notes", "Entry notes kept"),
               item("individual_student_discussion", "additional_notes", "Nil entries kept")
             ]
    end

    test "drops blank remarks and never reads checkbox, attendance or score fields",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => [
              %{
                "attendance" => "present",
                "questions" => %{
                  "empty" => %{"answer" => "yes", "remark" => ""},
                  "spaces" => %{"answer" => "no", "remark" => " \n\t "},
                  "number" => %{"score" => 4, "remark" => 4},
                  "checkbox_only" => %{"answer" => "yes"},
                  "kept" => %{"answer" => "no", "score" => 2, "remark" => "Needs lab support"}
                }
              }
            ]
          }
        },
        %{
          action_type: "individual_student_discussion",
          data: %{
            "entries" => [
              %{
                "grade" => 11,
                "questions" => %{
                  "blank" => %{"answer" => "yes", "remark" => "   "},
                  "nil" => %{"answer" => "no", "remark" => nil}
                }
              }
            ],
            "additional_notes" => "  "
          }
        }
      ])

      assert items(conn) == [
               item("individual_af_teacher_interaction", "Teacher 1: kept", "Needs lab support")
             ]
    end
  end

  describe "fingerprint" do
    test "changes with a per-teacher or per-entry remark but not with checkboxes or scores",
         %{conn: conn} do
      teacher_visit = insert_visit(%{}, [teacher_action("yes", 3, "Behind by two chapters")])
      entry_visit = insert_visit(%{}, [entry_action("yes", 3, "Finds organic chemistry hard")])

      assert [
               %{"visit_id" => ^teacher_visit, "fingerprint" => teacher_fingerprint},
               %{"visit_id" => ^entry_visit, "fingerprint" => entry_fingerprint}
             ] = pending_visits(conn, "prompt_version=v1")["visits"]

      insert_summary(teacher_visit, teacher_fingerprint, "v1")
      insert_summary(entry_visit, entry_fingerprint, "v1")

      set_action_data(teacher_visit, teacher_action("no", 1, "Behind by two chapters").data)
      set_action_data(entry_visit, entry_action("no", 1, "Finds organic chemistry hard").data)

      assert pending_ids(conn, "prompt_version=v1") == []

      set_action_data(teacher_visit, teacher_action("no", 1, "Caught up last week").data)
      assert pending_ids(conn, "prompt_version=v1") == [teacher_visit]

      set_action_data(entry_visit, entry_action("no", 1, "Now finds it easier").data)
      assert pending_ids(conn, "prompt_version=v1") == [teacher_visit, entry_visit]
    end
  end

  describe "class context in labels" do
    test "prefixes every classroom observation item with its grade and subject",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "classroom_observation",
          data: %{
            "grade" => "11",
            "subject_name" => " Physics ",
            "teacher_id" => 77,
            "teacher_name" => "Indrani Khan",
            "params" => %{"punctuality" => %{"score" => 1, "remarks" => "Late by 20 minutes"}},
            "observer_summary_improvements" => "Start on time",
            "additional_notes" => "Class started 20 minutes late"
          }
        },
        %{
          action_type: "classroom_observation",
          data: %{
            "grade" => 12,
            "observer_summary_strengths" => "Clear derivations"
          }
        }
      ])

      assert items(conn) == [
               item(
                 "classroom_observation",
                 "Grade 11 Physics class observation: punctuality",
                 "Late by 20 minutes"
               ),
               item(
                 "classroom_observation",
                 "Grade 11 Physics class observation: observer_summary_improvements",
                 "Start on time"
               ),
               item(
                 "classroom_observation",
                 "Grade 11 Physics class observation: additional_notes",
                 "Class started 20 minutes late"
               ),
               item(
                 "classroom_observation",
                 "Grade 12 class observation: observer_summary_strengths",
                 "Clear derivations"
               )
             ]
    end

    test "labels a teacher with the subject of the one teacher row its permission links to",
         %{conn: conn} do
      physics = insert_subject("Physics")
      chemistry = insert_subject("Chemistry")
      unnamed = insert_subject(nil)

      # Ids are LMS `user_permission` ids: a `teacher` row with the same id as
      # the permission (ids far past the sequences, so they cannot collide) is
      # someone else and must not be used.
      linked = insert_permission(insert_teacher_user([physics]), nil, 900_000_001)
      insert_teacher(insert_user(), chemistry, 900_000_001)
      email_only = insert_permission(nil, "email-only@example.com")
      insert_teacher_user([physics], "email-only@example.com")
      two_rows = insert_permission(insert_teacher_user([physics, chemistry]))
      no_subject = insert_permission(insert_teacher_user([nil]))
      no_english_name = insert_permission(insert_teacher_user([unnamed]))
      no_teacher = insert_permission(insert_user())

      teachers =
        Enum.map(
          [linked, email_only, two_rows, no_subject, no_english_name, no_teacher, 999_999_999],
          &%{
            "id" => &1,
            "name" => "SENTINEL-NAME",
            "questions" => %{"syllabus" => %{"remark" => "Behind by two chapters"}}
          }
        )

      insert_visit(%{}, [
        %{action_type: "individual_af_teacher_interaction", data: %{"teachers" => teachers}}
      ])

      assert Enum.map(items(conn), & &1["label"]) == [
               "Teacher 1 (Physics): syllabus",
               "Teacher 2: syllabus",
               "Teacher 3: syllabus",
               "Teacher 4: syllabus",
               "Teacher 5: syllabus",
               "Teacher 6: syllabus",
               "Teacher 7: syllabus"
             ]
    end

    test "a teacher's subject changing re-summarises the Visit", %{conn: conn} do
      user_id = insert_teacher_user([insert_subject("Physics")])
      permission_id = insert_permission(user_id)

      visit_id =
        insert_visit(%{}, [
          %{
            action_type: "individual_af_teacher_interaction",
            data: %{
              "teachers" => [
                %{"id" => permission_id, "questions" => %{"pace" => %{"remark" => "Too fast"}}}
              ]
            }
          }
        ])

      assert [%{"fingerprint" => fingerprint}] =
               pending_visits(conn, "prompt_version=v1")["visits"]

      insert_summary(visit_id, fingerprint, "v1")
      assert pending_ids(conn, "prompt_version=v1") == []

      Repo.query!("UPDATE teacher SET subject_id = $1 WHERE user_id = $2", [
        insert_subject("Maths"),
        user_id
      ])

      assert pending_ids(conn, "prompt_version=v1") == [visit_id]
    end

    test "never adds a classroom observation's teacher name to any label or text",
         %{conn: conn} do
      insert_visit(%{}, [
        %{
          action_type: "classroom_observation",
          data: %{
            "grade" => 11,
            "subject_name" => "Physics",
            "teacher_id" => 77,
            "teacher_name" => "SENTINEL-NAME",
            "params" => %{
              "board_work" => %{"remarks" => "Board is cluttered"},
              "rapport" => %{"remarks" => "SENTINEL-NAME knows every student"}
            },
            "observer_summary_strengths" => "Good rapport",
            "additional_notes" => "Class started 20 minutes late"
          }
        }
      ])

      items = items(conn)

      refute Enum.any?(items, &String.contains?(&1["label"], "SENTINEL-NAME"))

      # Only the remark that already named the teacher carries the name.
      assert [%{"text" => "SENTINEL-NAME knows every student"}] =
               Enum.filter(items, &String.contains?(&1["text"], "SENTINEL-NAME"))
    end
  end

  defp insert_subject(english_name) do
    name =
      if english_name,
        do: [%{"lang_code" => "en", "subject" => english_name}],
        else: [%{"lang_code" => "hi", "subject" => "विषय"}]

    insert_row("subject", %{name: name})
  end

  defp insert_user, do: insert_row("user", %{})

  defp insert_user(email), do: insert_row("user", %{email: email})

  # A user with one `teacher` row per subject id (nil for no subject).
  defp insert_teacher_user(subject_ids, email \\ nil) do
    user_id = if email, do: insert_user(email), else: insert_user()
    Enum.each(subject_ids, &insert_teacher(user_id, &1))
    user_id
  end

  defp insert_teacher(user_id, subject_id, id \\ nil) do
    attrs = %{user_id: user_id, subject_id: subject_id, is_af_teacher: true}
    insert_row("teacher", if(id, do: Map.put(attrs, :id, id), else: attrs))
  end

  defp insert_permission(user_id, email \\ nil, id \\ nil) do
    attrs = %{
      user_id: user_id,
      email: email || "teacher-#{System.unique_integer([:positive])}@example.com",
      level: 1
    }

    insert_row("user_permission", if(id, do: Map.put(attrs, :id, id), else: attrs))
  end

  defp insert_row(table, attrs) do
    now = ~N[2026-10-20 06:00:00]
    row = Map.merge(%{inserted_at: now, updated_at: now}, attrs)
    {1, [%{id: id}]} = Repo.insert_all(table, [row], returning: [:id])
    id
  end

  defp teacher_action(answer, score, remark) do
    %{
      action_type: "individual_af_teacher_interaction",
      data: %{
        "teachers" => [
          %{
            "name" => "Indrani Khan",
            "questions" => %{
              "syllabus" => %{"answer" => answer, "score" => score, "remark" => remark}
            }
          }
        ]
      }
    }
  end

  defp entry_action(answer, score, remark) do
    %{
      action_type: "individual_student_discussion",
      data: %{
        "entries" => [
          %{
            "grade" => 11,
            "students" => [%{"name" => "Asha Verma"}],
            "questions" => %{
              "concerns" => %{"answer" => answer, "score" => score, "remark" => remark}
            }
          }
        ]
      }
    }
  end

  defp items(conn) do
    assert [%{"items" => items}] = pending_visits(conn, "prompt_version=v1")["visits"]
    items
  end
end
