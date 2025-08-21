alias Dbservice.Repo
alias Dbservice.Grades.Grade

IO.puts("  → Seeding grades...")

# Indian education system grades (Classes 1-12)
grades_data = for grade_number <- 8..13 do
  %{number: grade_number}
end

# Insert grades if they don't exist
Enum.each(grades_data, fn grade_attrs ->
  unless Repo.get_by(Grade, number: grade_attrs.number) do
    %Grade{}
    |> Grade.changeset(grade_attrs)
    |> Repo.insert!()
  end
end)

IO.puts("    ✅ Grades seeded")
