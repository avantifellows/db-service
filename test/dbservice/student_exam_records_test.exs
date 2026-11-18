defmodule Dbservice.StudentExamRecordsTest do
  use Dbservice.DataCase

  alias Dbservice.StudentExamRecords
  alias Dbservice.Exams.StudentExamRecord

  import Dbservice.UsersFixtures

  # Both blocks hang their record on a student and an exam of their own.
  defp record_attrs do
    {_user, student} = student_fixture()
    {:ok, exam} = Dbservice.Exams.create_exam(%{name: "JEE Main #{System.unique_integer()}"})

    %{
      attrs: %{
        student_id: student.id,
        exam_id: exam.id,
        application_number: "APP#{System.unique_integer([:positive])}"
      }
    }
  end

  describe "student exam details" do
    setup do
      record_attrs()
    end

    test "create_student_exam_record/1 stores the exam contact details", %{attrs: attrs} do
      assert {:ok,
              %StudentExamRecord{
                exam_email: "student@example.com",
                exam_phone: "9876543210",
                exam_roll_no: "JE26010234",
                exam_year: 2026
              }} =
               StudentExamRecords.create_student_exam_record(
                 Map.merge(attrs, %{
                   exam_email: "  student@example.com  ",
                   exam_phone: "9876543210",
                   exam_roll_no: " JE26010234 ",
                   exam_year: 2026
                 })
               )
    end

    test "create_student_exam_record/1 blanks the string fields to nil", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{exam_email: nil, exam_phone: nil, exam_roll_no: nil}} =
               StudentExamRecords.create_student_exam_record(
                 Map.merge(attrs, %{exam_email: "   ", exam_phone: "", exam_roll_no: " "})
               )
    end

    test "create_student_exam_record/1 rejects an unreachable email", %{attrs: attrs} do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :exam_email, "student.example.com")
               )

      assert {"must be a valid email address", _} = changeset.errors[:exam_email]
    end

    test "create_student_exam_record/1 rejects a phone that is not plain digits", %{attrs: attrs} do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :exam_phone, "+91 98765 43210")
               )

      assert {"must contain only digits", _} = changeset.errors[:exam_phone]
    end

    test "create_student_exam_record/1 rejects a roll number longer than the column", %{
      attrs: attrs
    } do
      # Devanagari: 40 graphemes but 80 codepoints, which varchar(50) counts.
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :exam_roll_no, String.duplicate("नी", 40))
               )

      assert {"should be at most %{count} character(s)", _} = changeset.errors[:exam_roll_no]
    end

    test "create_student_exam_record/1 rejects an exam year outside the plausible range", %{
      attrs: attrs
    } do
      for year <- [202, 1989, Date.utc_today().year + 2] do
        assert {:error, changeset} =
                 StudentExamRecords.create_student_exam_record(Map.put(attrs, :exam_year, year))

        assert changeset.errors[:exam_year]
      end
    end

    test "update_student_exam_record/2 clears the exam details", %{attrs: attrs} do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.merge(attrs, %{
            exam_email: "student@example.com",
            exam_phone: "9876543210",
            exam_roll_no: "JE26010234",
            exam_year: 2026
          })
        )

      assert {:ok,
              %StudentExamRecord{
                exam_email: nil,
                exam_phone: nil,
                exam_roll_no: nil,
                exam_year: nil
              }} =
               StudentExamRecords.update_student_exam_record(record, %{
                 exam_email: nil,
                 exam_phone: nil,
                 exam_roll_no: nil,
                 exam_year: nil
               })
    end
  end

  describe "sessions applied" do
    setup do
      record_attrs()
    end

    test "create_student_exam_record/1 stores the sittings applied for", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: [1, 2]}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [1, 2])
               )
    end

    test "create_student_exam_record/1 stores the sittings as a sorted set", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: [1, 2]}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [2, 1, 2])
               )
    end

    test "create_student_exam_record/1 stores no sitting as nil", %{attrs: attrs} do
      assert {:ok, %StudentExamRecord{sessions_applied: nil}} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [])
               )
    end

    test "create_student_exam_record/1 rejects a session number no exam runs", %{attrs: attrs} do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :sessions_applied, [1, 7])
               )

      assert {"must be session numbers between 1 and 4", _} = changeset.errors[:sessions_applied]
    end

    test "update_student_exam_record/2 clears the sittings", %{attrs: attrs} do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(Map.put(attrs, :sessions_applied, [1]))

      assert {:ok, %StudentExamRecord{sessions_applied: nil}} =
               StudentExamRecords.update_student_exam_record(record, %{sessions_applied: []})
    end
  end

  describe "application password ciphertext" do
    setup do
      record_attrs()
    end

    @ciphertext "AQICAHhEeGFtcGxlLWttcy1jaXBoZXJ0ZXh0Lw+="

    test "create_student_exam_record/1 stores the ciphertext without plaintext", %{attrs: attrs} do
      assert {:ok,
              %StudentExamRecord{
                application_password_ciphertext: @ciphertext,
                application_password: nil
              }} =
               StudentExamRecords.create_student_exam_record(
                 attrs
                 |> Map.put(:application_password, "plain")
                 |> Map.put(:application_password_ciphertext, @ciphertext)
               )
    end

    test "update_student_exam_record/2 retires the plaintext once ciphertext is written", %{
      attrs: attrs
    } do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.put(attrs, :application_password, "legacy")
        )

      assert record.application_password == "legacy"

      assert {:ok,
              %StudentExamRecord{
                application_password: nil,
                application_password_ciphertext: @ciphertext
              }} =
               StudentExamRecords.update_student_exam_record(record, %{
                 "application_password_ciphertext" => @ciphertext
               })
    end

    test "update_student_exam_record/2 clears both when the ciphertext is cleared", %{
      attrs: attrs
    } do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.put(attrs, :application_password, "legacy")
        )

      assert {:ok,
              %StudentExamRecord{application_password: nil, application_password_ciphertext: nil}} =
               StudentExamRecords.update_student_exam_record(record, %{
                 application_password_ciphertext: nil
               })
    end

    test "update_student_exam_record/2 leaves the plaintext to a writer that does not send ciphertext",
         %{attrs: attrs} do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.put(attrs, :application_password, "legacy")
        )

      assert {:ok, %StudentExamRecord{application_password: "legacy"}} =
               StudentExamRecords.update_student_exam_record(record, %{sessions_applied: [1]})
    end

    test "update_student_exam_record/2 drops stale ciphertext when a new plaintext arrives", %{
      attrs: attrs
    } do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.put(attrs, :application_password_ciphertext, @ciphertext)
        )

      assert {:ok,
              %StudentExamRecord{
                application_password: "new-from-legacy-writer",
                application_password_ciphertext: nil
              }} =
               StudentExamRecords.update_student_exam_record(record, %{
                 "application_password" => "new-from-legacy-writer"
               })
    end

    test "update_student_exam_record/2 keeps the ciphertext when a legacy writer echoes a blank plaintext",
         %{attrs: attrs} do
      {:ok, record} =
        StudentExamRecords.create_student_exam_record(
          Map.put(attrs, :application_password_ciphertext, @ciphertext)
        )

      for blank <- [nil, "", "   "] do
        assert {:ok, %StudentExamRecord{application_password_ciphertext: @ciphertext}} =
                 StudentExamRecords.update_student_exam_record(record, %{
                   application_password: blank,
                   sessions_applied: [1]
                 })
      end
    end

    test "create_student_exam_record/1 rejects ciphertext that is not base64", %{attrs: attrs} do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :application_password_ciphertext, "plain password!")
               )

      assert {"must be base64-encoded ciphertext", _} =
               changeset.errors[:application_password_ciphertext]
    end

    test "create_student_exam_record/1 rejects ciphertext longer than KMS can produce", %{
      attrs: attrs
    } do
      assert {:error, changeset} =
               StudentExamRecords.create_student_exam_record(
                 Map.put(attrs, :application_password_ciphertext, String.duplicate("A", 8196))
               )

      assert changeset.errors[:application_password_ciphertext]
    end
  end
end
