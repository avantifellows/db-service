defmodule DbserviceWeb.HolisticMentorshipProfilePreflightControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  import Dbservice.GradesFixtures
  import Dbservice.SchoolsFixtures
  import Dbservice.UsersFixtures
  import ExUnit.CaptureLog

  @template_hash "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  @grade_11_source %{
    "af_session_id" => "EnableStudents_6a44a83d1184e717b920c499",
    "entry_grade" => 11,
    "form_id" => "6a44a83d1184e717b920c499"
  }
  @grade_12_source %{
    "af_session_id" => "EnableStudents_6a4deca8e030ebe34669fb0f",
    "entry_grade" => 12,
    "form_id" => "6a4deca8e030ebe34669fb0f"
  }

  test "preflights both approved Profile sources in input order with canonical Student IDs", %{
    conn: conn
  } do
    prompt_configuration_id = prompt_configuration_id(conn)
    {grade_11_user, grade_11_student} = eligible_student(11, "BUSINESS-G11")
    {grade_12_user, grade_12_student} = eligible_student(12, "BUSINESS-G12")

    response =
      conn
      |> post("/api/holistic-mentorship/profile-preflight", %{
        "records" => [
          record("second", grade_12_user.id, prompt_configuration_id, @grade_12_source),
          record("first", grade_11_user.id, prompt_configuration_id, @grade_11_source)
        ]
      })
      |> json_response(200)

    assert response == %{
             "results" => [
               %{
                 "record_ref" => "second",
                 "student_id" => grade_12_student.id,
                 "prompt_configuration_id" => prompt_configuration_id,
                 "profile_state" => "missing",
                 "profile_revision" => nil
               },
               %{
                 "record_ref" => "first",
                 "student_id" => grade_11_student.id,
                 "prompt_configuration_id" => prompt_configuration_id,
                 "profile_state" => "missing",
                 "profile_revision" => nil
               }
             ]
           }

    refute response |> inspect() =~ "BUSINESS-G"
  end

  test "keeps a Grade 11 journey after progression and rejects a conflicting Grade 12 source", %{
    conn: conn
  } do
    prompt_configuration_id = prompt_configuration_id(conn)
    {user, student} = eligible_student(11, "JOURNEY-G11")
    insert_journey!(student.id, @grade_11_source)

    grade_12 = grade_fixture(%{number: 12})
    Repo.query!("UPDATE student SET grade_id = $2 WHERE id = $1", [student.id, grade_12.id])

    Repo.query!(
      "UPDATE enrollment_record SET group_id = $2 WHERE user_id = $1 AND group_type = 'grade'",
      [user.id, grade_12.id]
    )

    response =
      conn
      |> post("/api/holistic-mentorship/profile-preflight", %{
        "records" => [
          record("original", user.id, prompt_configuration_id, @grade_11_source),
          record("conflict", user.id, prompt_configuration_id, @grade_12_source)
        ]
      })
      |> json_response(200)

    assert response == %{
             "results" => [
               %{
                 "record_ref" => "original",
                 "student_id" => student.id,
                 "prompt_configuration_id" => prompt_configuration_id,
                 "profile_state" => "missing",
                 "profile_revision" => nil
               },
               rejected("conflict", "journey_source_conflict")
             ]
           }
  end

  test "reports configuration-specific Profile state and revision from the answer fingerprint", %{
    conn: conn
  } do
    first_configuration_id = prompt_configuration_id(conn)
    second_configuration_id = prompt_configuration_id(conn, "google/gemini-2.5-flash")
    {user, student} = eligible_student(11, "PROFILE-STATE")
    journey_id = insert_journey!(student.id, @grade_11_source)
    insert_profile!(journey_id, first_configuration_id, "answers-v1", 7)

    baseline = record("unchanged", user.id, first_configuration_id, @grade_11_source)

    records = [
      Map.put(baseline, "answer_fingerprint", "answers-v1"),
      baseline
      |> Map.put("record_ref", "changed")
      |> Map.put("answer_fingerprint", "answers-v2"),
      record("other-configuration", user.id, second_configuration_id, @grade_11_source)
    ]

    assert conn
           |> post("/api/holistic-mentorship/profile-preflight", %{"records" => records})
           |> json_response(200) == %{
             "results" => [
               %{
                 "record_ref" => "unchanged",
                 "student_id" => student.id,
                 "prompt_configuration_id" => first_configuration_id,
                 "profile_state" => "unchanged",
                 "profile_revision" => 7
               },
               %{
                 "record_ref" => "changed",
                 "student_id" => student.id,
                 "prompt_configuration_id" => first_configuration_id,
                 "profile_state" => "changed_answers",
                 "profile_revision" => 7
               },
               %{
                 "record_ref" => "other-configuration",
                 "student_id" => student.id,
                 "prompt_configuration_id" => second_configuration_id,
                 "profile_state" => "missing",
                 "profile_revision" => nil
               }
             ]
           }
  end

  test "accepts 100 records and rejects 101 records wholly", %{conn: conn} do
    prompt_configuration_id = prompt_configuration_id(conn)
    {user, _student} = eligible_student(11, "BOUNDARY")

    records =
      for index <- 1..100 do
        record("record-#{index}", user.id, prompt_configuration_id, @grade_11_source)
      end

    assert %{"results" => results} =
             conn
             |> post("/api/holistic-mentorship/profile-preflight", %{"records" => records})
             |> json_response(200)

    assert length(results) == 100

    assert conn
           |> post("/api/holistic-mentorship/profile-preflight", %{
             "records" => [hd(records) | records]
           })
           |> json_response(422) == %{
             "error" => %{
               "code" => "batch_too_large",
               "message" => "Profile Preflight accepts at most 100 records"
             }
           }
  end

  test "rejects an empty or missing records batch safely", %{conn: conn} do
    for params <- [%{"records" => []}, %{"records" => ["not-a-record"]}, %{}] do
      assert conn
             |> post("/api/holistic-mentorship/profile-preflight", params)
             |> json_response(422) == %{
               "error" => %{
                 "code" => "invalid_request",
                 "message" => "Profile Preflight requires 1 through 100 records"
               }
             }
    end
  end

  test "rejects missing or oversized record references and answer fingerprints wholly", %{
    conn: conn
  } do
    prompt_configuration_id = prompt_configuration_id(conn)
    {user, _student} = eligible_student(11, "INVALID-ENVELOPE")

    baseline = record("valid-ref", user.id, prompt_configuration_id, @grade_11_source)

    invalid_records = [
      Map.delete(baseline, "record_ref"),
      Map.put(baseline, "record_ref", ""),
      Map.put(baseline, "record_ref", 123),
      Map.put(baseline, "record_ref", String.duplicate("r", 256)),
      Map.delete(baseline, "answer_fingerprint"),
      Map.put(baseline, "answer_fingerprint", ""),
      Map.put(baseline, "answer_fingerprint", 123),
      Map.put(baseline, "answer_fingerprint", String.duplicate("f", 256))
    ]

    for invalid_record <- invalid_records do
      assert conn
             |> post("/api/holistic-mentorship/profile-preflight", %{
               "records" => [baseline, invalid_record]
             })
             |> json_response(422) == %{
               "error" => %{
                 "code" => "invalid_request",
                 "message" => "Profile Preflight requires 1 through 100 records"
               }
             }
    end
  end

  test "returns stable safe codes for source, identity, Form, and Prompt rejections", %{
    conn: conn
  } do
    prompt_configuration_id = prompt_configuration_id(conn)
    {eligible_user, _student} = eligible_student(11, "SAFE-CODES")
    user_without_student = user_fixture()
    {ambiguous_user, ambiguous_student} = eligible_student(11, "AMBIGUOUS")

    {:ok, _duplicate_student} =
      Dbservice.Users.create_student(%{
        user_id: ambiguous_user.id,
        grade_id: ambiguous_student.grade_id,
        status: "active",
        student_id: "AMBIGUOUS-SECOND"
      })

    baseline = record("baseline", eligible_user.id, prompt_configuration_id, @grade_11_source)

    records = [
      Map.merge(baseline, %{"record_ref" => "malformed", "source_user_id" => "not-an-id"}),
      Map.merge(baseline, %{"record_ref" => "test", "source_record_type" => "test"}),
      Map.merge(baseline, %{"record_ref" => "no-user", "source_user_id" => "2000000000"}),
      Map.merge(baseline, %{
        "record_ref" => "no-student",
        "source_user_id" => Integer.to_string(user_without_student.id)
      }),
      Map.merge(baseline, %{
        "record_ref" => "ambiguous",
        "source_user_id" => Integer.to_string(ambiguous_user.id)
      }),
      Map.merge(baseline, %{"record_ref" => "bad-form", "form_id" => "unknown"}),
      Map.merge(baseline, %{"record_ref" => "wrong-grade", "entry_grade" => 12}),
      Map.merge(baseline, %{
        "record_ref" => "no-prompt",
        "prompt_configuration_id" => 2_000_000_000
      }),
      Map.merge(baseline, %{
        "record_ref" => "bad-prompt-type",
        "prompt_configuration_id" => "not-an-id"
      })
    ]

    assert conn
           |> post("/api/holistic-mentorship/profile-preflight", %{"records" => records})
           |> json_response(200) == %{
             "results" => [
               rejected("malformed", "malformed_source_id"),
               rejected("test", "test_record"),
               rejected("no-user", "user_not_found"),
               rejected("no-student", "student_not_found"),
               rejected("ambiguous", "ambiguous_student"),
               rejected("bad-form", "form_not_approved"),
               rejected("wrong-grade", "form_grade_mismatch"),
               rejected("no-prompt", "prompt_configuration_not_found"),
               rejected("bad-prompt-type", "prompt_configuration_not_found")
             ]
           }
  end

  test "rejects out-of-scope, duplicate, and inconsistent current eligibility", %{conn: conn} do
    prompt_configuration_id = prompt_configuration_id(conn)
    {program_user, _student} = eligible_student(11, "NO-PROGRAM")
    {school_program_user, _student} = eligible_student(11, "SCHOOL-NO-PROGRAM")
    {school_user, _student} = eligible_student(11, "NO-SCHOOL")
    {duplicate_school_user, _student} = eligible_student(11, "TWO-SCHOOLS")
    {duplicate_program_user, _student} = eligible_student(11, "TWO-PROGRAMS")
    {grade_10_user, _student} = eligible_student(10, "GRADE-10")
    {missing_grade_user, _student} = eligible_student(11, "NO-GRADE")
    {duplicate_grade_user, duplicate_grade_student} = eligible_student(11, "TWO-GRADES")
    {mismatched_grade_user, _student} = eligible_student(11, "GRADE-MISMATCH")
    {dropout_user, _student} = eligible_student(11, "DROPOUT")

    Repo.query!(
      "UPDATE enrollment_record SET group_id = 2 WHERE user_id = $1 AND group_type = 'program'",
      [program_user.id]
    )

    Repo.query!(
      """
      UPDATE school SET program_ids = '{}'
      FROM enrollment_record
      WHERE enrollment_record.user_id = $1
        AND enrollment_record.group_type = 'school'
        AND school.id = enrollment_record.group_id
      """,
      [school_program_user.id]
    )

    Repo.query!(
      "DELETE FROM enrollment_record WHERE user_id = $1 AND group_type = 'school'",
      [school_user.id]
    )

    second_school = school_fixture(%{program_ids: [1], code: "second-school"})
    enroll(duplicate_school_user.id, "school", second_school.id)
    enroll(duplicate_program_user.id, "program", 1)

    Repo.query!("DELETE FROM enrollment_record WHERE user_id = $1 AND group_type = 'grade'", [
      missing_grade_user.id
    ])

    enroll(duplicate_grade_user.id, "grade", duplicate_grade_student.grade_id)

    grade_12 = grade_fixture(%{number: 12})

    Repo.query!(
      "UPDATE enrollment_record SET group_id = $2 WHERE user_id = $1 AND group_type = 'grade'",
      [mismatched_grade_user.id, grade_12.id]
    )

    Repo.query!("UPDATE student SET status = 'dropout' WHERE user_id = $1", [dropout_user.id])

    records = [
      preflight_record("program", program_user.id, prompt_configuration_id),
      preflight_record("school-program", school_program_user.id, prompt_configuration_id),
      preflight_record("school", school_user.id, prompt_configuration_id),
      preflight_record("two-schools", duplicate_school_user.id, prompt_configuration_id),
      preflight_record("two-programs", duplicate_program_user.id, prompt_configuration_id),
      preflight_record("grade-10", grade_10_user.id, prompt_configuration_id),
      preflight_record("no-grade", missing_grade_user.id, prompt_configuration_id),
      preflight_record("two-grades", duplicate_grade_user.id, prompt_configuration_id),
      preflight_record("grade-mismatch", mismatched_grade_user.id, prompt_configuration_id),
      preflight_record("dropout", dropout_user.id, prompt_configuration_id)
    ]

    assert conn
           |> post("/api/holistic-mentorship/profile-preflight", %{"records" => records})
           |> json_response(200) == %{
             "results" => [
               rejected("program", "program_ineligible"),
               rejected("school-program", "program_ineligible"),
               rejected("school", "school_missing_or_ambiguous"),
               rejected("two-schools", "school_missing_or_ambiguous"),
               rejected("two-programs", "eligibility_inconsistent"),
               rejected("grade-10", "grade_ineligible"),
               rejected("no-grade", "grade_ineligible"),
               rejected("two-grades", "eligibility_inconsistent"),
               rejected("grade-mismatch", "eligibility_inconsistent"),
               rejected("dropout", "dropout")
             ]
           }
  end

  test "does not expose source or canonical identifiers and Profile content in rejection logs", %{
    conn: conn
  } do
    prompt_configuration_id = prompt_configuration_id(conn)
    {user, student} = eligible_student(11, "SENSITIVE-BUSINESS-ID")
    Repo.query!("UPDATE student SET status = 'dropout' WHERE id = $1", [student.id])

    sensitive_answer = "sensitive-answer-fingerprint"

    {conn, log} =
      with_debug_log(fn ->
        post(conn, "/api/holistic-mentorship/profile-preflight", %{
          "records" => [
            preflight_record("safe-ref", user.id, prompt_configuration_id)
            |> Map.put("answer_fingerprint", sensitive_answer)
          ]
        })
      end)

    assert json_response(conn, 200) == %{
             "results" => [rejected("safe-ref", "dropout")]
           }

    refute conn.resp_body =~ Integer.to_string(user.id)
    refute conn.resp_body =~ Integer.to_string(student.id)
    refute conn.resp_body =~ sensitive_answer
    refute log =~ "\"source_user_id\" => \"#{user.id}\""
    refute log =~ "\"student_id\" => #{student.id}"
    refute log =~ sensitive_answer
  end

  defp eligible_student(grade_number, business_student_id) do
    grade = grade_fixture(%{number: grade_number})

    {user, student} =
      student_fixture(%{
        grade_id: grade.id,
        status: "active",
        student_id: business_student_id
      })

    school = school_fixture(%{program_ids: [1], code: "school-#{user.id}"})

    enroll(user.id, "school", school.id)
    enroll(user.id, "program", 1)
    enroll(user.id, "grade", grade.id)

    {user, student}
  end

  defp enroll(user_id, group_type, group_id) do
    {:ok, _enrollment} =
      Dbservice.EnrollmentRecords.create_enrollment_record(%{
        user_id: user_id,
        group_id: group_id,
        group_type: group_type,
        academic_year: "2026-27",
        start_date: ~D[2026-06-01],
        is_current: true
      })
  end

  defp prompt_configuration_id(conn, model_id \\ "openai/gpt-5-mini") do
    response =
      conn
      |> post("/api/holistic-mentorship/prompt-configurations", %{
        "prompt_version" => "profile-preflight-v1",
        "template_text" => "abc",
        "template_hash" => @template_hash,
        "model_id" => model_id
      })
      |> json_response(200)

    response["id"]
  end

  defp record(record_ref, user_id, prompt_configuration_id, source) do
    Map.merge(source, %{
      "answer_fingerprint" => "answer-fingerprint",
      "prompt_configuration_id" => prompt_configuration_id,
      "record_ref" => record_ref,
      "source_record_type" => "production",
      "source_user_id" => Integer.to_string(user_id)
    })
  end

  defp preflight_record(record_ref, user_id, prompt_configuration_id) do
    record(record_ref, user_id, prompt_configuration_id, @grade_11_source)
  end

  defp rejected(record_ref, reason_code) do
    %{"record_ref" => record_ref, "reason_code" => reason_code}
  end

  defp insert_journey!(student_id, source) do
    [[journey_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_profile_journeys
          (student_id, form_id, af_session_id, entry_grade)
        VALUES ($1, $2, $3, $4)
        RETURNING id
        """,
        [student_id, source["form_id"], source["af_session_id"], source["entry_grade"]]
      ).rows

    journey_id
  end

  defp insert_profile!(journey_id, configuration_id, answer_fingerprint, revision) do
    [[profile_id]] =
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profiles
          (profile_journey_id, prompt_configuration_id, schema_fingerprint,
           answer_fingerprint, warehouse_loaded_at, generated_at, revision,
           last_successful_etl_run_id)
        VALUES ($1, $2, 'schema-v1', $3, '2026-07-16 10:00:00',
                '2026-07-16 10:05:00', $4, 'etl-run-1')
        RETURNING id
        """,
        [journey_id, configuration_id, answer_fingerprint, revision]
      ).rows

    for position <- 1..5 do
      Repo.query!(
        """
        INSERT INTO holistic_mentorship_student_profile_summaries
          (student_profile_id, position, question_set_title, summary)
        VALUES ($1, $2, $3, $4)
        """,
        [profile_id, position, "Question Set #{position}", "Summary #{position}"]
      )
    end
  end

  defp with_debug_log(operation) do
    previous_level = Logger.level()
    Logger.configure(level: :debug)

    try do
      with_log([level: :debug], operation)
    after
      Logger.configure(level: previous_level)
    end
  end
end
