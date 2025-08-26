import Ecto.Query
alias Dbservice.Repo

IO.puts("  → Seeding learning objectives...")

# Learning objectives data with multilingual support (English and Hindi)
learning_objectives_data = [
  # Mathematics Learning Objectives
  %{
    title: [
      %{"value" => "Understand the concept of linear equations and their applications", "lang" => "en"},
      %{"value" => "रैखिक समीकरणों की अवधारणा और उनके अनुप्रयोगों को समझना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Solve quadratic equations using various methods", "lang" => "en"},
      %{"value" => "विभिन्न विधियों का उपयोग करके द्विघात समीकरणों को हल करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Apply trigonometric ratios to solve real-world problems", "lang" => "en"},
      %{"value" => "वास्तविक जीवन की समस्याओं को हल करने के लिए त्रिकोणमितीय अनुपात लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Calculate derivatives of functions using differentiation rules", "lang" => "en"},
      %{"value" => "अवकलन नियमों का उपयोग करके फलनों के अवकलज की गणना करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Evaluate definite and indefinite integrals", "lang" => "en"},
      %{"value" => "निश्चित और अनिश्चित समाकलनों का मूल्यांकन करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Perform matrix operations and solve linear systems", "lang" => "en"},
      %{"value" => "आव्यूह संक्रियाएं करना और रैखिक निकायों को हल करना", "lang" => "hi"}
    ]
  },

  # Physics Learning Objectives
  %{
    title: [
      %{"value" => "Apply Newton's laws to analyze motion and forces", "lang" => "en"},
      %{"value" => "गति और बलों का विश्लेषण करने के लिए न्यूटन के नियमों को लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Use kinematic equations to solve motion problems", "lang" => "en"},
      %{"value" => "गति समस्याओं को हल करने के लिए गतिकी समीकरणों का उपयोग करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand work, energy, and power relationships", "lang" => "en"},
      %{"value" => "कार्य, ऊर्जा और शक्ति के संबंधों को समझना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Apply Coulomb's law to electrostatic problems", "lang" => "en"},
      %{"value" => "स्थिर विद्युत समस्याओं के लिए कूलॉम्ब के नियम को लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Analyze electrical circuits using Ohm's law", "lang" => "en"},
      %{"value" => "ओम के नियम का उपयोग करके विद्युत परिपथों का विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand electromagnetic induction and its applications", "lang" => "en"},
      %{"value" => "विद्युत चुम्बकीय प्रेरण और इसके अनुप्रयोगों को समझना", "lang" => "hi"}
    ]
  },

  # Chemistry Learning Objectives
  %{
    title: [
      %{"value" => "Describe atomic structure and electron configuration", "lang" => "en"},
      %{"value" => "परमाणु संरचना और इलेक्ट्रॉन विन्यास का वर्णन करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Explain chemical bonding theories and molecular shapes", "lang" => "en"},
      %{"value" => "रासायनिक बंधन सिद्धांतों और आणविक आकारों की व्याख्या करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Use periodic trends to predict element properties", "lang" => "en"},
      %{"value" => "तत्व गुणों की भविष्यवाणी के लिए आवर्त प्रवृत्तियों का उपयोग करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Perform stoichiometric calculations in chemical reactions", "lang" => "en"},
      %{"value" => "रासायनिक अभिक्रियाओं में रसायनमितीय गणना करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Balance and analyze redox reactions", "lang" => "en"},
      %{"value" => "अपचयोपचय अभिक्रियाओं को संतुलित करना और विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand organic reaction mechanisms", "lang" => "en"},
      %{"value" => "कार्बनिक अभिक्रिया तंत्रों को समझना", "lang" => "hi"}
    ]
  },

  # Biology Learning Objectives
  %{
    title: [
      %{"value" => "Describe the processes of mitosis and meiosis", "lang" => "en"},
      %{"value" => "माइटोसिस और मिओसिस की प्रक्रियाओं का वर्णन करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Explain the mechanism of photosynthesis", "lang" => "en"},
      %{"value" => "प्रकाश संश्लेषण के तंत्र की व्याख्या करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand cellular respiration and energy production", "lang" => "en"},
      %{"value" => "कोशिकीय श्वसन और ऊर्जा उत्पादन को समझना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Apply principles of genetics to inheritance patterns", "lang" => "en"},
      %{"value" => "वंशानुक्रम पैटर्न में आनुवंशिकता के सिद्धांतों को लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Analyze evolutionary relationships and natural selection", "lang" => "en"},
      %{"value" => "विकासवादी संबंधों और प्राकृतिक चयन का विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand ecosystem interactions and energy flow", "lang" => "en"},
      %{"value" => "पारिस्थितिकी तंत्र की परस्पर क्रिया और ऊर्जा प्रवाह को समझना", "lang" => "hi"}
    ]
  },

  # Computer Science Learning Objectives
  %{
    title: [
      %{"value" => "Implement and analyze various data structures", "lang" => "en"},
      %{"value" => "विभिन्न डेटा संरचनाओं को लागू करना और विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Design and analyze efficient algorithms", "lang" => "en"},
      %{"value" => "कुशल एल्गोरिदम डिजाइन करना और विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Apply object-oriented programming principles", "lang" => "en"},
      %{"value" => "वस्तु उन्मुख प्रोग्रामिंग सिद्धांतों को लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Design and implement database systems", "lang" => "en"},
      %{"value" => "डेटाबेस सिस्टम डिजाइन करना और लागू करना", "lang" => "hi"}
    ]
  },

  # English Learning Objectives
  %{
    title: [
      %{"value" => "Apply grammatical rules in written and spoken communication", "lang" => "en"},
      %{"value" => "लिखित और मौखिक संचार में व्याकरणिक नियमों को लागू करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Analyze literary works and identify themes", "lang" => "en"},
      %{"value" => "साहित्यिक कृतियों का विश्लेषण करना और विषयों की पहचान करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Write effective essays and compositions", "lang" => "en"},
      %{"value" => "प्रभावी निबंध और रचनाएं लिखना", "lang" => "hi"}
    ]
  },

  # Economics Learning Objectives
  %{
    title: [
      %{"value" => "Analyze market dynamics using supply and demand principles", "lang" => "en"},
      %{"value" => "आपूर्ति और मांग सिद्धांतों का उपयोग करके बाजार गतिशीलता का विश्लेषण करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Evaluate different market structures and their characteristics", "lang" => "en"},
      %{"value" => "विभिन्न बाजार संरचनाओं और उनकी विशेषताओं का मूल्यांकन करना", "lang" => "hi"}
    ]
  },
  %{
    title: [
      %{"value" => "Understand the causes and effects of inflation", "lang" => "en"},
      %{"value" => "मुद्रास्फीति के कारणों और प्रभावों को समझना", "lang" => "hi"}
    ]
  }
]

# Fetch all available concepts to assign randomly
all_concepts = Repo.all(from c in "concept", select: %{id: c.id})

IO.puts("  → Found #{length(all_concepts)} concepts")

if length(all_concepts) == 0 do
  IO.puts("  ⚠️  No concepts found. Skipping learning objectives seeding.")
else
  # Function to randomly assign concept_id
  get_random_concept_id = fn -> Enum.random(all_concepts).id end

  # Prepare learning objectives data for bulk insert
  learning_objectives_to_insert =
    for objective_attrs <- learning_objectives_data do
      # Check if learning objective already exists by title
      objective_title = objective_attrs.title

      existing = Repo.all(from lo in "learning_objective", where: lo.title == ^objective_title, select: lo.id)

      if length(existing) == 0 do
        %{
          title: objective_title,
          concept_id: get_random_concept_id.(),
          inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      else
        nil
      end
    end
    |> Enum.filter(&(&1 != nil))

  if length(learning_objectives_to_insert) > 0 do
    try do
      {count, _} = Repo.insert_all("learning_objective", learning_objectives_to_insert)
      IO.puts("  ✅ Created #{count} learning objective records")
    rescue
      e ->
        IO.puts("  ⚠️  Error inserting learning objectives: #{inspect(e)}")

        # Try individual inserts
        learning_objectives_created =
          for attrs <- learning_objectives_to_insert do
            try do
              Repo.insert_all("learning_objective", [attrs])
              1
            rescue
              _error -> 0
            end
          end
          |> Enum.sum()

        IO.puts("  ✅ Created #{learning_objectives_created} learning objective records (individual inserts)")
    end
  else
    IO.puts("  → All learning objectives already exist")
  end
end
