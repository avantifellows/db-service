alias Dbservice.Repo

IO.puts("→ Seeding languages...")

# Language data from dump
languages_data = [
  %{name: "English", code: "en"},
  %{name: "Hindi", code: "hi"},
  %{name: "Tamil", code: "ta"},
  %{name: "Gujarati", code: "gu"}
]

languages_created =
  for language_data <- languages_data do
    # Check if language already exists by code
    existing_language = Repo.get_by(Dbservice.Languages.Language, code: language_data.code)

    if existing_language do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Languages.Language{} |> Dbservice.Languages.Language.changeset(language_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{languages_created} languages")
