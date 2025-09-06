alias Dbservice.Repo
alias Dbservice.Concepts.Concept
alias Dbservice.Topics.Topic

IO.puts("  → Seeding concepts...")

# Comprehensive concept data with multilingual support (English and Hindi)
concepts_data = [
  # Mathematics Concepts
  %{
    name: [
      %{"value" => "Linear Equations", "lang" => "en"},
      %{"value" => "रैखिक समीकरण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Quadratic Equations", "lang" => "en"},
      %{"value" => "द्विघात समीकरण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Trigonometric Ratios", "lang" => "en"},
      %{"value" => "त्रिकोणमितीय अनुपात", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Derivatives", "lang" => "en"},
      %{"value" => "अवकलज", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Integration", "lang" => "en"},
      %{"value" => "समाकलन", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Matrices", "lang" => "en"},
      %{"value" => "आव्यूह", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Probability", "lang" => "en"},
      %{"value" => "प्रायिकता", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Statistics", "lang" => "en"},
      %{"value" => "सांख्यिकी", "lang" => "hi"}
    ]
  },

  # Physics Concepts
  %{
    name: [
      %{"value" => "Newton's Laws", "lang" => "en"},
      %{"value" => "न्यूटन के नियम", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Kinematic Equations", "lang" => "en"},
      %{"value" => "गतिकी समीकरण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Work Energy Theorem", "lang" => "en"},
      %{"value" => "कार्य-ऊर्जा प्रमेय", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Coulomb's Law", "lang" => "en"},
      %{"value" => "कूलॉम्ब का नियम", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Ohm's Law", "lang" => "en"},
      %{"value" => "ओम का नियम", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Electromagnetic Induction", "lang" => "en"},
      %{"value" => "विद्युत चुम्बकीय प्रेरण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Wave Optics", "lang" => "en"},
      %{"value" => "तरंग प्रकाशिकी", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Thermodynamics", "lang" => "en"},
      %{"value" => "ऊष्मागतिकी", "lang" => "hi"}
    ]
  },

  # Chemistry Concepts
  %{
    name: [
      %{"value" => "Atomic Structure", "lang" => "en"},
      %{"value" => "परमाणु संरचना", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Chemical Bonding", "lang" => "en"},
      %{"value" => "रासायनिक बंधन", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Periodic Table", "lang" => "en"},
      %{"value" => "आवर्त सारणी", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Stoichiometry", "lang" => "en"},
      %{"value" => "रसायनमिति", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Redox Reactions", "lang" => "en"},
      %{"value" => "अपचयोपचय अभिक्रियाएं", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Organic Reactions", "lang" => "en"},
      %{"value" => "कार्बनिक अभिक्रियाएं", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Thermochemistry", "lang" => "en"},
      %{"value" => "ऊष्मारसायन", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Chemical Equilibrium", "lang" => "en"},
      %{"value" => "रासायनिक साम्यावस्था", "lang" => "hi"}
    ]
  },

  # Biology Concepts
  %{
    name: [
      %{"value" => "Cell Division", "lang" => "en"},
      %{"value" => "कोशिका विभाजन", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Photosynthesis", "lang" => "en"},
      %{"value" => "प्रकाश संश्लेषण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Respiration", "lang" => "en"},
      %{"value" => "श्वसन", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Genetics", "lang" => "en"},
      %{"value" => "आनुवंशिकता", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Evolution", "lang" => "en"},
      %{"value" => "विकास", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Ecology", "lang" => "en"},
      %{"value" => "पारिस्थितिकी", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Biomolecules", "lang" => "en"},
      %{"value" => "जैव अणु", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Human Physiology", "lang" => "en"},
      %{"value" => "मानव शरीर क्रिया विज्ञान", "lang" => "hi"}
    ]
  },

  # Computer Science Concepts
  %{
    name: [
      %{"value" => "Data Structures", "lang" => "en"},
      %{"value" => "डेटा संरचनाएं", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Algorithms", "lang" => "en"},
      %{"value" => "एल्गोरिदम", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Object Oriented Programming", "lang" => "en"},
      %{"value" => "वस्तु उन्मुख प्रोग्रामिंग", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Database Management", "lang" => "en"},
      %{"value" => "डेटाबेस प्रबंधन", "lang" => "hi"}
    ]
  },

  # English Concepts
  %{
    name: [
      %{"value" => "Grammar", "lang" => "en"},
      %{"value" => "व्याकरण", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Literature", "lang" => "en"},
      %{"value" => "साहित्य", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Composition", "lang" => "en"},
      %{"value" => "रचना", "lang" => "hi"}
    ]
  },

  # Economics Concepts
  %{
    name: [
      %{"value" => "Supply and Demand", "lang" => "en"},
      %{"value" => "आपूर्ति और मांग", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Market Structure", "lang" => "en"},
      %{"value" => "बाजार संरचना", "lang" => "hi"}
    ]
  },
  %{
    name: [
      %{"value" => "Inflation", "lang" => "en"},
      %{"value" => "मुद्रास्फीति", "lang" => "hi"}
    ]
  }
]

# Fetch all available topics to assign randomly
all_topics = Repo.all(Topic)

if length(all_topics) == 0 do
  IO.puts("  ⚠️  No topics found. Skipping concept seeding.")
else
  # Function to randomly assign topic_id
  get_random_topic_id = fn -> Enum.random(all_topics).id end

  # Create concepts with random topic assignments
  concepts_created =
    for concept_attrs <- concepts_data do
      # Check if concept already exists by name
      concept_name = concept_attrs.name

      unless Repo.get_by(Concept, name: concept_name) do
        attrs = %{
          name: concept_name,
          topic_id: get_random_topic_id.()
        }

        case %Concept{} |> Concept.changeset(attrs) |> Repo.insert() do
          {:ok, _} -> 1
          {:error, changeset} ->
            IO.puts("  ⚠️  Failed to create concept: #{inspect(changeset.errors)}")
            0
        end
      else
        0
      end
    end
    |> Enum.sum()

  IO.puts("  ✅ Created #{concepts_created} concept records")
end
