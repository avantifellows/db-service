defmodule Dbservice.VisitConcerns.ExtractionTest do
  @moduledoc """
  Label class context in `Extraction.items/2`: grade and subject, never names.
  """
  use ExUnit.Case, async: true

  alias Dbservice.VisitConcerns.Extraction

  describe "classroom_observation labels" do
    test "prefix every item with the grade and subject" do
      assert labels(observation(%{"grade" => 11, "subject_name" => "Physics"})) == [
               "Grade 11 Physics class observation: board_work",
               "Grade 11 Physics class observation: observer_summary_strengths",
               "Grade 11 Physics class observation: observer_summary_improvements",
               "Grade 11 Physics class observation: additional_notes"
             ]
    end

    test "accept a digit-string grade" do
      assert [first | _] = labels(observation(%{"grade" => "12", "subject_name" => "Maths"}))
      assert first == "Grade 12 Maths class observation: board_work"
    end

    test "use the grade alone when there is no subject" do
      for data <- [
            %{"grade" => 11},
            %{"grade" => 11, "subject_name" => nil},
            %{"grade" => 11, "subject_name" => "  \n "},
            %{"grade" => 11, "subject_name" => 4}
          ] do
        assert [first | _] = labels(observation(data))
        assert first == "Grade 11 class observation: board_work"
      end
    end

    test "use the subject alone when there is no valid grade" do
      for data <- [
            %{"subject_name" => "  Physics "},
            %{"grade" => nil, "subject_name" => "Physics"}
          ] do
        assert [first | _] = labels(observation(data))
        assert first == "Physics class observation: board_work"
      end
    end

    test "keep today's labels when there is neither" do
      assert labels(observation(%{})) == [
               "board_work",
               "observer_summary_strengths",
               "observer_summary_improvements",
               "additional_notes"
             ]

      assert labels(observation(%{"grade" => "", "subject_name" => ""})) ==
               labels(observation(%{}))
    end

    test "ignore a grade that is not a positive integer or a digit string" do
      for grade <- [0, -11, 11.0, "11.0", " 11", "11a", "eleven", "XI", "0", "100", 100, [11]] do
        assert [first | _] =
                 labels(observation(%{"grade" => grade, "subject_name" => "Physics"})),
               "grade #{inspect(grade)}"

        assert first == "Physics class observation: board_work", "grade #{inspect(grade)}"
      end
    end

    test "collapse whitespace in the subject and cap it at 40 characters" do
      long = "Advanced   Theoretical\nPhysics and Applied Mathematics for Grade Twelve"

      assert [first | _] = labels(observation(%{"grade" => 12, "subject_name" => long}))

      assert first ==
               "Grade 12 Advanced Theoretical Physics and Applied class observation: board_work"

      assert String.length("Advanced Theoretical Physics and Applied") == 40
    end

    test "never put the teacher's name in a label" do
      data = %{
        "grade" => 11,
        "subject_name" => "Physics",
        "teacher_id" => 77,
        "teacher_name" => "SENTINEL-NAME"
      }

      refute Enum.any?(labels(observation(data)), &String.contains?(&1, "SENTINEL-NAME"))
    end
  end

  describe "individual_af_teacher_interaction labels" do
    test "add the looked-up subject by teacher id, never the name" do
      action = %{
        id: 1,
        action_type: "individual_af_teacher_interaction",
        data: %{
          "teachers" => [
            teacher(41, "SENTINEL-NAME", "Behind by two chapters"),
            teacher(42, "Ravi Sharma", "On track"),
            teacher("41", "String id", "Not looked up")
          ]
        }
      }

      assert Extraction.items([action], %{41 => "Physics"}) |> Enum.map(& &1.label) == [
               "Teacher 1 (Physics): syllabus",
               "Teacher 2: syllabus",
               "Teacher 3: syllabus"
             ]

      assert Extraction.items([action]) |> Enum.map(& &1.label) == [
               "Teacher 1: syllabus",
               "Teacher 2: syllabus",
               "Teacher 3: syllabus"
             ]
    end

    test "teacher_ids lists the distinct positive integer ids" do
      actions = [
        %{
          id: 1,
          action_type: "individual_af_teacher_interaction",
          data: %{
            "teachers" => [
              %{"id" => 41},
              %{"id" => 42},
              %{"id" => 41},
              %{"id" => "43"},
              %{"id" => 0},
              %{"id" => 9_223_372_036_854_775_808},
              %{"name" => "No id"},
              "not a map"
            ]
          }
        },
        %{id: 2, action_type: "individual_af_teacher_interaction", data: %{"teachers" => "x"}},
        %{id: 3, action_type: "classroom_observation", data: %{"teachers" => [%{"id" => 44}]}},
        %{id: 4, action_type: "individual_af_teacher_interaction", data: nil}
      ]

      assert Extraction.teacher_ids(actions) == [41, 42]
    end
  end

  test "subject_text trims, collapses and caps a subject name" do
    assert Extraction.subject_text("  Physics ") == "Physics"
    assert Extraction.subject_text("Business\n\tEconomics") == "Business Economics"
    assert Extraction.subject_text(String.duplicate("a", 41)) == String.duplicate("a", 40)
    assert Extraction.subject_text(String.duplicate("a", 39) <> " b") == String.duplicate("a", 39)
    assert Extraction.subject_text("   ") == nil
    assert Extraction.subject_text(nil) == nil
  end

  defp observation(extra) do
    %{
      id: 1,
      action_type: "classroom_observation",
      data:
        Map.merge(
          %{
            "params" => %{"board_work" => %{"score" => 2, "remarks" => "Board is cluttered"}},
            "observer_summary_strengths" => "Good rapport",
            "observer_summary_improvements" => "Pace is too fast",
            "additional_notes" => "Class started 20 minutes late"
          },
          extra
        )
    }
  end

  defp teacher(id, name, remark) do
    %{
      "id" => id,
      "name" => name,
      "attendance" => "present",
      "questions" => %{"syllabus" => %{"answer" => "no", "remark" => remark}}
    }
  end

  defp labels(action), do: [action] |> Extraction.items() |> Enum.map(& &1.label)
end
