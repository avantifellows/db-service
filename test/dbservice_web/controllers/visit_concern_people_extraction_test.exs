defmodule DbserviceWeb.VisitConcernPeopleExtractionTest do
  @moduledoc """
  Per-teacher and per-student-entry Visit Concern extraction through
  GET /api/visit-concerns/pending-visits. Labels come from positions and keys,
  never from a teacher's or a Student's name.
  """
  use DbserviceWeb.ConnCase

  import Dbservice.VisitConcernsFixtures

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
