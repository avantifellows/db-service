import Ecto.Query
alias Dbservice.Repo

IO.puts("  → Seeding chapters...")

# Fetch all grades and subjects from database
all_grades = Repo.all(from g in "grade", select: %{id: g.id, number: g.number})
all_subjects = Repo.all(from s in "subject", select: %{id: s.id, name: s.name})

IO.puts("  → Found #{length(all_grades)} grades and #{length(all_subjects)} subjects")

if length(all_grades) == 0 or length(all_subjects) == 0 do
  IO.puts("  ⚠️  No grades or subjects found. Skipping chapters seeding.")
else
  # Helper to pick a random existing grade and subject pair
  pick_random_pair = fn ->
    {Enum.random(all_grades), Enum.random(all_subjects)}
  end

  # Base chapter data (no grade/subject attached)
  base_chapters = [
    %{code: "11P1", name: [%{"chapter" => "Mathematical Tools", "lang_code" => "en"}]},
    %{code: "11P7", name: [%{"chapter" => "Friction", "lang_code" => "en"}]},
    %{code: "11P12", name: [%{"chapter" => "Gravitation", "lang_code" => "en"}]},
    %{code: "11P13", name: [%{"chapter" => "Elasticity and Viscosity", "lang_code" => "en"}]},
    %{code: "12P23", name: [%{"chapter" => "Current Electricity", "lang_code" => "en"}]},
    %{code: "12P26", name: [%{"chapter" => "Electromagnetic Induction", "lang_code" => "en"}]},
    %{code: "12P28", name: [%{"chapter" => "Geometrical Optics", "lang_code" => "en"}]},
    %{code: "12P30", name: [%{"chapter" => "Modern Physics", "lang_code" => "en"}]},
    %{code: "12P32", name: [%{"chapter" => "Semiconductor", "lang_code" => "en"}]},
    %{code: "12P34", name: [%{"chapter" => "Principles of Communication", "lang_code" => "en"}]},
    %{code: "11M6", name: [%{"chapter" => "Permutation and Combination", "lang_code" => "en"}]},
    %{code: "11M10", name: [%{"chapter" => "Circle", "lang_code" => "en"}]},
    %{code: "11M12", name: [%{"chapter" => "Statistics", "lang_code" => "en"}]},
    %{code: "11M14", name: [%{"chapter" => "Solution Of Triangle", "lang_code" => "en"}]},
    %{code: "12M15", name: [%{"chapter" => "Function and Inverse Trigonometric Functions", "lang_code" => "en"}]},
    %{code: "12M22", name: [%{"chapter" => "Vector and 3D", "lang_code" => "en"}]},
    %{code: "11C2", name: [%{"chapter" => "Atomic Structure", "lang_code" => "en"}]},
    %{code: "11C5", name: [%{"chapter" => "Gaseous State", "lang_code" => "en"}]},
    %{code: "11C7", name: [%{"chapter" => "Chemical Equilibrium", "lang_code" => "en"}]},
    %{code: "11C8", name: [%{"chapter" => "Ionic Equilibrium", "lang_code" => "en"}]},
    %{code: "11C9", name: [%{"chapter" => "Redox Reaction", "lang_code" => "en"}]},
    %{code: "11C12", name: [%{"chapter" => "The s-Block Elements", "lang_code" => "en"}]},
    %{code: "11C16", name: [%{"chapter" => "Hydrocarbons", "lang_code" => "en"}]},
    %{code: "12C20", name: [%{"chapter" => "Electrochemistry", "lang_code" => "en"}]},
    %{code: "12C27", name: [%{"chapter" => "Coordination Compounds", "lang_code" => "en"}]},
    %{code: "12C39", name: [%{"chapter" => "Amines", "lang_code" => "en"}]},
    %{code: "12C43", name: [%{"chapter" => "Principles Related to Practical Chemistry", "lang_code" => "en"}]},
    %{code: "11B2", name: [%{"chapter" => "Biological Classification", "lang_code" => "en"}]},
    %{code: "11B3", name: [%{"chapter" => "Plant Kingdom", "lang_code" => "en"}]},
    %{code: "11B5", name: [%{"chapter" => "Morphology Of Flowering Plants", "lang_code" => "en"}]},
    %{code: "11B6", name: [%{"chapter" => "Anatomy Of Flowering Plants", "lang_code" => "en"}]},
    %{code: "11B11", name: [%{"chapter" => "Transport In Plants", "lang_code" => "en"}]},
    %{code: "11B14", name: [%{"chapter" => "Respiration In Plants", "lang_code" => "en"}]},
    %{code: "11B15", name: [%{"chapter" => "Plant Growth and Development", "lang_code" => "en"}]},
    %{code: "11B16", name: [%{"chapter" => "Digestion and Absorption", "lang_code" => "en"}]},
    %{code: "12B24", name: [%{"chapter" => "Sexual Reproduction In Flowering Plants", "lang_code" => "en"}]},
    %{code: "12B25", name: [%{"chapter" => "Human Reproduction", "lang_code" => "en"}]},
    %{code: "12B28", name: [%{"chapter" => "Molecular Basis Of Inheritance", "lang_code" => "en"}]},
    %{code: "12B33", name: [%{"chapter" => "Biotechnology - Principles and Processes", "lang_code" => "en"}]}
  ]

  # Attach a random existing grade and subject to each base chapter
  chapters_data =
    Enum.map(base_chapters, fn chapter ->
      {grade, subject} = pick_random_pair.()
      Map.merge(chapter, %{
        grade_id: grade.id,
        subject_id: subject.id
      })
    end)
    |> Enum.filter(fn c -> c.grade_id != nil and c.subject_id != nil end)

  IO.puts("  → Will create #{length(chapters_data)} chapters (with random existing grade/subject pairs)")

  # Get existing chapters to avoid duplicates
  existing_codes =
    from(c in "chapter", select: c.code)
    |> Repo.all()
    |> MapSet.new()

  IO.puts("  → Found #{MapSet.size(existing_codes)} existing chapters")

  # Filter out chapters that already exist
  chapters_to_insert =
    Enum.filter(chapters_data, fn chapter ->
      not MapSet.member?(existing_codes, chapter.code)
    end)
    |> Enum.map(fn chapter ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Map.merge(chapter, %{inserted_at: now, updated_at: now})
    end)

  if length(chapters_to_insert) > 0 do
    try do
      {count, _} = Repo.insert_all("chapter", chapters_to_insert)
      IO.puts("  ✅ Created #{count} chapters")
    rescue
      e ->
        IO.puts("  ⚠️  Error inserting chapters: #{inspect(e)}")

        # Try individual inserts
        chapters_created =
          for chapter_attrs <- chapters_to_insert do
            try do
              Repo.insert_all("chapter", [chapter_attrs])
              1
            rescue
              _error -> 0
            end
          end
          |> Enum.sum()

        IO.puts("  ✅ Created #{chapters_created} chapters (individual inserts)")
    end
  else
    IO.puts("  → All chapters already exist")
  end
end
