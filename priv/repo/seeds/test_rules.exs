alias Dbservice.Repo
alias Dbservice.TestRules.TestRule
alias Dbservice.Exams.Exam

IO.puts("→ Seeding test rules...")

# Get all exams
exams = Repo.all(Exam)

if Enum.empty?(exams) do
  IO.puts("    ⚠️  No exams found. Skipping test rules seeding.")
else
  # Test rule configurations with marking schemes
  test_rule_configs = [
    %{
      test_type: "MCQ",
      config: %{
        "marking_scheme" => %{
          "correct_marks" => 4,
          "incorrect_marks" => -1,
          "unanswered_marks" => 0
        },
        "time_per_question" => 60,
        "total_questions" => 90,
        "sections" => [
          %{"name" => "Physics", "questions" => 30},
          %{"name" => "Chemistry", "questions" => 30},
          %{"name" => "Mathematics", "questions" => 30}
        ]
      }
    },
    %{
      test_type: "Subjective",
      config: %{
        "marking_scheme" => %{
          "total_marks" => 300,
          "negative_marking" => false
        },
        "time_limit" => 180,
        "sections" => [
          %{"name" => "Theory", "marks" => 200},
          %{"name" => "Numerical", "marks" => 100}
        ]
      }
    },
    %{
      test_type: "Mixed",
      config: %{
        "marking_scheme" => %{
          "mcq_correct" => 4,
          "mcq_incorrect" => -1,
          "subjective_total" => 100
        },
        "time_limit" => 150,
        "sections" => [
          %{"name" => "MCQ", "questions" => 60, "marks" => 240},
          %{"name" => "Subjective", "questions" => 10, "marks" => 100}
        ]
      }
    },
    %{
      test_type: "Aptitude",
      config: %{
        "marking_scheme" => %{
          "correct_marks" => 3,
          "incorrect_marks" => -1,
          "unanswered_marks" => 0
        },
        "time_per_question" => 90,
        "total_questions" => 100,
        "sections" => [
          %{"name" => "Logical Reasoning", "questions" => 35},
          %{"name" => "Quantitative Aptitude", "questions" => 35},
          %{"name" => "English Comprehension", "questions" => 30}
        ]
      }
    },
    %{
      test_type: "NEET_Pattern",
      config: %{
        "marking_scheme" => %{
          "correct_marks" => 4,
          "incorrect_marks" => -1,
          "unanswered_marks" => 0
        },
        "time_limit" => 180,
        "total_questions" => 180,
        "sections" => [
          %{"name" => "Physics", "questions" => 45},
          %{"name" => "Chemistry", "questions" => 45},
          %{"name" => "Botany", "questions" => 45},
          %{"name" => "Zoology", "questions" => 45}
        ]
      }
    },
    %{
      test_type: "JEE_Pattern",
      config: %{
        "marking_scheme" => %{
          "mcq_correct" => 4,
          "mcq_incorrect" => -1,
          "numerical_correct" => 4,
          "numerical_incorrect" => 0
        },
        "time_limit" => 180,
        "sections" => [
          %{"name" => "Physics", "mcq" => 20, "numerical" => 10},
          %{"name" => "Chemistry", "mcq" => 20, "numerical" => 10},
          %{"name" => "Mathematics", "mcq" => 20, "numerical" => 10}
        ]
      }
    }
  ]

  test_rules_created =
    for exam <- exams do
      # Assign 1-3 test rules per exam
      num_rules = :rand.uniform(3)
      selected_configs = Enum.take_random(test_rule_configs, num_rules)

      for config <- selected_configs do
        # Check if this exam-test_type combination already exists
        existing_rule = Repo.get_by(TestRule, [
          exam_id: exam.id,
          test_type: config.test_type
        ])

        if existing_rule do
          0  # Already exists
        else
          test_rule_attrs = %{
            exam_id: exam.id,
            test_type: config.test_type,
            config: config.config
          }

          case Repo.insert(%TestRule{} |> TestRule.changeset(test_rule_attrs)) do
            {:ok, _} -> 1
            {:error, _} -> 0
          end
        end
      end
    end
    |> List.flatten()
    |> Enum.sum()

  IO.puts("    ✅ Created #{test_rules_created} test rules")
end
