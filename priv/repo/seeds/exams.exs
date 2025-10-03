alias Dbservice.Repo
alias Dbservice.Exams.Exam

IO.puts("→ Seeding exams...")

exam_names = [
  "State CET",
  "NEET",
  "KCET",
  "CUET",
  "JEE",
  "NDA"
]

exams_created =
  for name <- exam_names do
    unless Repo.get_by(Exam, name: name) do
      %Exam{}
      |> Exam.changeset(%{name: name})
      |> Repo.insert!()
      1
    else
      0
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{exams_created} exams")
