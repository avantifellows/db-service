alias Dbservice.Repo
alias Dbservice.Subjects.Subject

IO.puts("  → Seeding subjects...")

# Common subjects in Indian education system with support for English (en) and Hindi (hi)
subjects_data = [
  %{
    name: [
      %{"subject" => "Mathematics", "lang_code" => "en"},
      %{"subject" => "गणित", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Physics", "lang_code" => "en"},
      %{"subject" => "भौतिक विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Chemistry", "lang_code" => "en"},
      %{"subject" => "रसायन विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Biology", "lang_code" => "en"},
      %{"subject" => "जीव विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Botany", "lang_code" => "en"},
      %{"subject" => "वनस्पति विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Zoology", "lang_code" => "en"},
      %{"subject" => "प्राणी विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "English", "lang_code" => "en"},
      %{"subject" => "अंग्रेजी", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Hindi", "lang_code" => "en"},
      %{"subject" => "हिंदी", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "History", "lang_code" => "en"},
      %{"subject" => "इतिहास", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Geography", "lang_code" => "en"},
      %{"subject" => "भूगोल", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Economics", "lang_code" => "en"},
      %{"subject" => "अर्थशास्त्र", "lang_code" => "hi"}
    ],
    code: nil
  },
  %{
    name: [
      %{"subject" => "Computer Science", "lang_code" => "en"},
      %{"subject" => "कंप्यूटर विज्ञान", "lang_code" => "hi"}
    ],
    code: nil
  }
]

# Insert subjects if they don't exist (using name for uniqueness check)
Enum.each(subjects_data, fn subject_attrs ->

  unless Repo.get_by(Subject, [name: subject_attrs.name]) do
    %Subject{}
    |> Subject.changeset(subject_attrs)
    |> Repo.insert!()
  end
end)

IO.puts("    ✅ Subjects seeded")
