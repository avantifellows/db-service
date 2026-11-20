defmodule DbserviceWeb.BlendedLearningMentorControllerTest do
  use DbserviceWeb.ConnCase, async: false

  alias Dbservice.Repo

  @contact_keys ~w(phone whatsapp_phone email)

  describe "GET /api/blended-learning/mentor" do
    test "returns the running mentor for the student's user id", %{conn: conn} do
      scope = insert_scope()
      assign!(scope, scope.mentor_user_id, "2026-2027", "2026-06-01 00:00:00")

      assert conn
             |> get("/api/blended-learning/mentor", %{"user_id" => scope.student_user_id})
             |> json_response(200) == %{
               "academic_year" => "2026-2027",
               "program_id" => scope.program_id,
               "started_at" => "2026-06-01T00:00:00",
               "mentor" => %{
                 "user_id" => scope.mentor_user_id,
                 "first_name" => "Mentor",
                 "last_name" => "Private"
               }
             }
    end

    test "returns no phone, whatsapp number or email at any nesting level", %{conn: conn} do
      scope = insert_scope()
      assign!(scope, scope.mentor_user_id, "2026-2027", "2026-06-01 00:00:00")

      response_conn =
        get(conn, "/api/blended-learning/mentor", %{"user_id" => scope.student_user_id})

      body = json_response(response_conn, 200)

      assert body
             |> collect_keys()
             |> MapSet.intersection(MapSet.new(@contact_keys))
             |> Enum.empty?()

      for private <- ["9000000803", "9000000806", "mentor.private@example.org"] do
        refute response_conn.resp_body =~ private
      end
    end

    test "ignores a mapping that has ended, so a past mentor is never returned", %{conn: conn} do
      scope = insert_scope()
      assign!(scope, scope.mentor_user_id, "2026-2027", "2026-06-01 00:00:00")
      end_mapping!(scope.student_user_id)

      assert conn
             |> get("/api/blended-learning/mentor", %{"user_id" => scope.student_user_id})
             |> json_response(404) == %{
               "error" => %{
                 "code" => "mentor_mapping_not_found",
                 "message" => "Student has no running mentor mapping"
               }
             }
    end

    test "returns the most recently started mapping when two years run at once", %{conn: conn} do
      scope = insert_scope()
      later_mentor = insert_user!("Later", "Private", "later.private@example.org", "9000000807")

      assign!(scope, scope.mentor_user_id, "2025-2026", "2025-06-01 00:00:00")
      assign!(scope, later_mentor, "2026-2027", "2026-06-01 00:00:00")

      assert conn
             |> get("/api/blended-learning/mentor", %{"user_id" => scope.student_user_id})
             |> json_response(200)
             |> Map.fetch!("mentor")
             |> Map.fetch!("user_id") == later_mentor
    end

    test "academic_year narrows to that year's mapping", %{conn: conn} do
      scope = insert_scope()
      later_mentor = insert_user!("Later", "Private", "later.private@example.org", "9000000808")

      assign!(scope, scope.mentor_user_id, "2025-2026", "2025-06-01 00:00:00")
      assign!(scope, later_mentor, "2026-2027", "2026-06-01 00:00:00")

      assert conn
             |> get("/api/blended-learning/mentor", %{
               "user_id" => scope.student_user_id,
               "academic_year" => "2025-2026"
             })
             |> json_response(200)
             |> Map.fetch!("mentor")
             |> Map.fetch!("user_id") == scope.mentor_user_id
    end

    test "404s for a student with no mapping, and for an unknown user", %{conn: conn} do
      scope = insert_scope()

      for user_id <- [scope.student_user_id, 9_999_999] do
        assert conn
               |> get("/api/blended-learning/mentor", %{"user_id" => user_id})
               |> json_response(404)
               |> get_in(["error", "code"]) == "mentor_mapping_not_found"
      end
    end

    test "400s when user_id is missing or not an integer", %{conn: conn} do
      for params <- [%{}, %{"user_id" => ""}, %{"user_id" => "abc"}, %{"user_id" => "12x"}] do
        assert conn
               |> get("/api/blended-learning/mentor", params)
               |> json_response(400)
               |> get_in(["error", "code"]) == "invalid_request"
      end
    end

    test "requires the existing Bearer token" do
      for authorization <- [nil, "Token malformed", "Bearer wrong-environment-secret"] do
        conn =
          if authorization,
            do: put_req_header(build_conn(), "authorization", authorization),
            else: build_conn()

        assert conn
               |> get("/api/blended-learning/mentor", %{"user_id" => 1})
               |> response(401) == "Not Authorized"
      end
    end
  end

  defp insert_scope do
    student_user_id =
      insert_user!("Asha", "Private", "asha.private@example.org", "9000000806")

    mentor_user_id =
      insert_user!("Mentor", "Private", "mentor.private@example.org", "9000000803")

    [[student_id]] =
      Repo.query!(
        """
        INSERT INTO student (user_id, inserted_at, updated_at)
        VALUES ($1, now(), now())
        RETURNING id
        """,
        [student_user_id]
      ).rows

    [[product_id]] =
      Repo.query!(
        "INSERT INTO product (name, inserted_at, updated_at) VALUES ('BL Mentor API', now(), now()) RETURNING id"
      ).rows

    [[program_id]] =
      Repo.query!(
        "INSERT INTO program (name, product_id, inserted_at, updated_at) VALUES ('BL Mentor API', $1, now(), now()) RETURNING id",
        [product_id]
      ).rows

    %{
      student_user_id: student_user_id,
      student_id: student_id,
      mentor_user_id: mentor_user_id,
      program_id: program_id
    }
  end

  defp insert_user!(first_name, last_name, email, phone) do
    [[id]] =
      Repo.query!(
        """
        INSERT INTO "user"
          (first_name, last_name, email, phone, whatsapp_phone, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $4, now(), now())
        RETURNING id
        """,
        [first_name, last_name, email, phone]
      ).rows

    id
  end

  defp assign!(scope, mentor_user_id, academic_year, started_at) do
    Repo.query!(
      """
      INSERT INTO blended_learning_mentor_mentee_mappings
        (student_id, mentor_user_id, program_id, academic_year, started_at,
         assignment_source, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, 'data_import', now(), now())
      """,
      [
        scope.student_id,
        mentor_user_id,
        scope.program_id,
        academic_year,
        NaiveDateTime.from_iso8601!(started_at)
      ]
    )
  end

  defp end_mapping!(student_user_id) do
    Repo.query!(
      """
      UPDATE blended_learning_mentor_mentee_mappings m
      SET ended_at = now(), end_source = 'data_import', end_reason = 'mentor_reassigned'
      FROM student s
      WHERE s.id = m.student_id AND s.user_id = $1
      """,
      [student_user_id]
    )
  end

  defp collect_keys(value) when is_map(value) do
    Enum.reduce(value, MapSet.new(Map.keys(value)), fn {_key, nested}, acc ->
      MapSet.union(acc, collect_keys(nested))
    end)
  end

  defp collect_keys(value) when is_list(value) do
    Enum.reduce(value, MapSet.new(), fn nested, acc ->
      MapSet.union(acc, collect_keys(nested))
    end)
  end

  defp collect_keys(_value), do: MapSet.new()
end
