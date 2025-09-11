alias Dbservice.Repo
alias Dbservice.Exams.StudentExamRecord
alias Dbservice.Exams.Exam
alias Dbservice.Users.Student

IO.puts("→ Seeding student exam records...")

students = Repo.all(Student)
exams = Repo.all(Exam)

if Enum.empty?(students) or Enum.empty?(exams) do
  IO.puts("    ⚠️  No students or exams found. Skipping student exam records seeding.")
else
  student_exam_records_created =
    students
    |> Enum.map(fn student ->
      exam = Enum.random(exams)

      attrs = %{
        student_id: student.id,
        exam_id: exam.id,
        application_number: :crypto.strong_rand_bytes(6) |> Base.encode16(case: :lower) |> binary_part(0, 12)
      }

      unless Repo.get_by(StudentExamRecord, student_id: attrs.student_id, exam_id: attrs.exam_id) do
        %StudentExamRecord{}
        |> StudentExamRecord.changeset(attrs)
        |> Repo.insert!()
        1
      else
        0
      end
    end)
    |> Enum.sum()

  IO.puts("    ✅ Created #{student_exam_records_created} student exam records")
end
