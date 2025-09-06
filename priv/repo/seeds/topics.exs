alias Dbservice.Repo
alias Dbservice.Topics.Topic
alias Dbservice.Chapters.Chapter

IO.puts("  → Seeding topics...")

# Get all chapters
chapters = Repo.all(Chapter)

if Enum.empty?(chapters) do
  IO.puts("    ⚠️  No chapters found. Skipping topics seeding.")
else
  # Topic data with bilingual names (English and Hindi)
  topic_templates = [
    # Physics topics
    %{name_en: "Introduction", name_hi: "परिचय"},
    %{name_en: "Basic Concepts", name_hi: "मूल अवधारणाएं"},
    %{name_en: "Applications", name_hi: "अनुप्रयोग"},
    %{name_en: "Problem Solving", name_hi: "समस्या समाधान"},
    %{name_en: "Derivations", name_hi: "व्युत्पत्ति"},
    %{name_en: "Practical Examples", name_hi: "व्यावहारिक उदाहरण"},
    %{name_en: "Advanced Concepts", name_hi: "उन्नत अवधारणाएं"},

    # Chemistry topics
    %{name_en: "Theory", name_hi: "सिद्धांत"},
    %{name_en: "Chemical Reactions", name_hi: "रासायनिक अभिक्रियाएं"},
    %{name_en: "Laboratory Methods", name_hi: "प्रयोगशाला विधियां"},
    %{name_en: "Industrial Applications", name_hi: "औद्योगिक अनुप्रयोग"},

    # Mathematics topics
    %{name_en: "Definitions", name_hi: "परिभाषाएं"},
    %{name_en: "Properties", name_hi: "गुण"},
    %{name_en: "Theorems", name_hi: "प्रमेय"},
    %{name_en: "Solved Examples", name_hi: "हल किए गए उदाहरण"},
    %{name_en: "Practice Problems", name_hi: "अभ्यास समस्याएं"},

    # Biology topics
    %{name_en: "Structure", name_hi: "संरचना"},
    %{name_en: "Function", name_hi: "कार्य"},
    %{name_en: "Classification", name_hi: "वर्गीकरण"},
    %{name_en: "Life Processes", name_hi: "जैविक प्रक्रियाएं"},
    %{name_en: "Evolution", name_hi: "विकास"}
  ]

  topics_created =
    for chapter <- chapters do
      # Generate 3-6 topics per chapter
      num_topics = :rand.uniform(4) + 2  # 3-6 topics
      selected_templates = Enum.take_random(topic_templates, num_topics)

      for {template, index} <- Enum.with_index(selected_templates, 1) do
        # Create unique code for each topic
        chapter_code = chapter.code || "CH#{chapter.id}"
        topic_code = "#{chapter_code}T#{String.pad_leading(Integer.to_string(index), 2, "0")}"

        # Check if topic already exists by code
        existing_topic = Repo.get_by(Topic, code: topic_code)

        if existing_topic do
          0  # Already exists
        else
          topic_attrs = %{
            code: topic_code,
            name: [
              %{"topic" => template.name_en, "lang_code" => "en"},
              %{"topic" => template.name_hi, "lang_code" => "hi"}
            ],
            chapter_id: chapter.id
          }

          case Repo.insert(%Topic{} |> Topic.changeset(topic_attrs)) do
            {:ok, _} -> 1
            {:error, _} -> 0
          end
        end
      end
    end
    |> List.flatten()
    |> Enum.sum()

  IO.puts("    ✅ Created #{topics_created} topics")
end
