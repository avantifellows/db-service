defmodule Dbservice.DataImport.BlendedMentorAssignmentProcessorTest do
  use Dbservice.DataCase

  alias Dbservice.DataImport.BlendedMentorAssignmentProcessor, as: Processor
  alias Dbservice.Users

  import Dbservice.UsersFixtures
  import Dbservice.ProgramsFixtures

  @table "blended_learning_mentor_mentee_mappings"

  setup do
    {_user, student} =
      student_fixture(%{student_id: "BL#{System.unique_integer([:positive])}"})

    program = program_fixture(%{name: "Blended #{System.unique_integer([:positive])}"})

    %{student: student, program: program}
  end

  describe "process_mentor_assignment/1 assignment" do
    test "assigns a mentor and creates the mentor user when the email is new", ctx do
      email = "rhea.iyer#{System.unique_integer([:positive])}@example.org"

      assert {:ok, message} =
               Processor.process_mentor_assignment(record(ctx, %{"mentor_email" => email}))

      assert message == "Mentor #{email} assigned"

      mentor = Users.get_user_by_email(email)
      assert mentor.first_name == "Rhea"
      assert mentor.last_name == "Iyer"
      assert mentor.role == "mentor"

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["mentor_user_id"] == mentor.id
      assert mapping["program_id"] == ctx.program.id
      assert mapping["academic_year"] == "2026-2027"
      assert mapping["assignment_source"] == "data_import"
      assert mapping["assigned_by_email"] == "ops@example.org"
      assert mapping["ended_at"] == nil
      # Blended is not attached to a physical school.
      assert mapping["school_id"] == nil
    end

    test "reuses an existing user instead of creating a second one", ctx do
      existing = user_fixture(%{email: "Mentor.One@Example.org", role: "mentor"})

      assert {:ok, _message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{"mentor_email" => "mentor.one@example.org"})
               )

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["mentor_user_id"] == existing.id
      assert users_with_email("mentor.one@example.org") == 0
    end

    test "records the assigner's user id when they have one", ctx do
      assigner = user_fixture(%{email: "ops.lead#{System.unique_integer([:positive])}@af.org"})

      assert {:ok, _message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{"assigned_by_email" => assigner.email})
               )

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["assigned_by_user_id"] == assigner.id
      assert mapping["assigned_by_email"] == assigner.email
    end

    test "leaves assigned_by_user_id blank for an assigner with no user record", ctx do
      assert {:ok, _message} = Processor.process_mentor_assignment(record(ctx))

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["assigned_by_user_id"] == nil
      assert mapping["assigned_by_email"] == "ops@example.org"
    end

    test "backdates started_at when the sheet supplies one", ctx do
      assert {:ok, _message} =
               Processor.process_mentor_assignment(record(ctx, %{"started_at" => "2026-07-01"}))

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["started_at"] == ~N[2026-07-01 00:00:00]
    end

    test "defaults started_at to now when the sheet leaves it blank", ctx do
      before = NaiveDateTime.utc_now() |> NaiveDateTime.add(-5, :second)

      assert {:ok, _message} =
               Processor.process_mentor_assignment(record(ctx, %{"started_at" => "  "}))

      assert [mapping] = mappings_for(ctx.student.id)
      assert NaiveDateTime.compare(mapping["started_at"], before) in [:gt, :eq]
    end

    test "accepts an ISO-8601 date and time for started_at", ctx do
      assert {:ok, _message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{"started_at" => "2026-07-01T09:30:00Z"})
               )

      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["started_at"] == ~N[2026-07-01 09:30:00]
    end
  end

  describe "process_mentor_assignment/1 reassignment" do
    test "is a no-op when the same mentor is already running", ctx do
      assert {:ok, _message} = Processor.process_mentor_assignment(record(ctx))

      assert {:ok, message} = Processor.process_mentor_assignment(record(ctx))
      assert message =~ "already assigned, no change"

      assert [_only_one] = mappings_for(ctx.student.id)
    end

    test "ends the running mapping and starts a new one for a different mentor", ctx do
      assert {:ok, _message} =
               Processor.process_mentor_assignment(record(ctx, %{"started_at" => "2026-07-01"}))

      assert {:ok, message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{
                   "mentor_email" => "second.mentor@example.org",
                   "started_at" => "2026-10-01",
                   "assignment_audit_reason" => "First mentor left the program"
                 })
               )

      assert message =~ "previous mapping ended"

      assert [ended, running] = mappings_for(ctx.student.id)

      # The old mapping is retained, closed at the moment the new one begins.
      assert ended["ended_at"] == ~N[2026-10-01 00:00:00]
      assert ended["end_reason"] == "mentor_reassigned"
      assert ended["end_source"] == "data_import"
      assert ended["ended_by_email"] == "ops@example.org"
      assert ended["end_audit_reason"] == "First mentor left the program"

      assert running["ended_at"] == nil
      assert running["started_at"] == ~N[2026-10-01 00:00:00]
      assert running["mentor_user_id"] == Users.get_user_by_email("second.mentor@example.org").id
    end

    test "leaves a mapping in another academic year alone", ctx do
      assert {:ok, _message} =
               Processor.process_mentor_assignment(record(ctx, %{"academic_year" => "2025-2026"}))

      assert {:ok, _message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{"mentor_email" => "second.mentor@example.org"})
               )

      assert [first, second] = mappings_for(ctx.student.id)
      assert first["academic_year"] == "2025-2026"
      assert first["ended_at"] == nil
      assert second["academic_year"] == "2026-2027"
      assert second["ended_at"] == nil
    end

    test "rejects a started_at that precedes the running mapping", ctx do
      assert {:ok, _message} =
               Processor.process_mentor_assignment(record(ctx, %{"started_at" => "2026-10-01"}))

      assert {:error, message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{
                   "mentor_email" => "second.mentor@example.org",
                   "started_at" => "2026-07-01"
                 })
               )

      assert message =~ "is before the running mapping's started_at"

      # The running mapping survives the rejected row untouched.
      assert [mapping] = mappings_for(ctx.student.id)
      assert mapping["ended_at"] == nil
    end
  end

  describe "process_mentor_assignment/1 validation" do
    test "reports an unknown student", ctx do
      record = record(ctx, %{"student_id" => "NO_SUCH_STUDENT"})

      assert {:error, message} = Processor.process_mentor_assignment(record)
      assert message =~ "Student not found"
    end

    test "reports an unknown program by name", ctx do
      record =
        ctx
        |> record()
        |> Map.delete("program_id")
        |> Map.put("program_name", "Not A Program")

      assert {:error, "Program not found with name: Not A Program"} =
               Processor.process_mentor_assignment(record)
    end

    test "requires a mentor name when the mentor has no user record yet", ctx do
      record =
        ctx
        |> record(%{"mentor_email" => "unknown.mentor@example.org"})
        |> Map.delete("mentor_first_name")

      assert {:error, message} = Processor.process_mentor_assignment(record)
      assert message =~ "mentor_first_name is required to create one"
      assert mappings_for(ctx.student.id) == []
    end

    test "requires assigned_by_email", ctx do
      assert {:error, "assigned_by_email is required"} =
               Processor.process_mentor_assignment(record(ctx, %{"assigned_by_email" => ""}))
    end

    test "requires academic_year", ctx do
      assert {:error, "academic_year is required"} =
               Processor.process_mentor_assignment(record(ctx, %{"academic_year" => " "}))
    end

    # Row processors are expected to return errors, not raise: an exception is
    # reported as a bare message with no context about the row's data.
    test "turns a database rejection into a row error", ctx do
      oversized_year = String.duplicate("2026-2027 ", 40)

      assert {:error, message} =
               Processor.process_mentor_assignment(
                 record(ctx, %{"academic_year" => oversized_year})
               )

      assert message =~ "Mentor assignment failed"
      assert mappings_for(ctx.student.id) == []
    end

    test "rejects an unparseable started_at", ctx do
      assert {:error, message} =
               Processor.process_mentor_assignment(record(ctx, %{"started_at" => "01-07-2026"}))

      assert message =~ "is not a valid date"
      assert mappings_for(ctx.student.id) == []
    end
  end

  # The worker hands the processor a record keyed by db_field, with program_id
  # already resolved from program_name.
  defp record(ctx, overrides \\ %{}) do
    %{
      "student_id" => ctx.student.student_id,
      "program_name" => ctx.program.name,
      "program_id" => ctx.program.id,
      "academic_year" => "2026-2027",
      "mentor_email" => "rhea.iyer@example.org",
      "mentor_first_name" => "Rhea",
      "mentor_last_name" => "Iyer",
      "assigned_by_email" => "ops@example.org"
    }
    |> Map.merge(overrides)
  end

  defp mappings_for(student_id) do
    %{columns: columns, rows: rows} =
      Repo.query!(
        "SELECT * FROM #{@table} WHERE student_id = $1 ORDER BY id ASC",
        [student_id]
      )

    Enum.map(rows, &(columns |> Enum.zip(&1) |> Map.new()))
  end

  defp users_with_email(email) do
    Repo.query!("SELECT count(*) FROM \"user\" WHERE email = $1", [email]).rows
    |> hd()
    |> hd()
  end
end
