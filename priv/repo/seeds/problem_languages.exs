alias Dbservice.Repo
alias Dbservice.Resources.ProblemLanguage
alias Dbservice.Resources.Resource
alias Dbservice.Languages.Language
import Ecto.Query

IO.puts("  → Seeding problem languages...")

# Fetch all available languages and resources from database
all_languages = Repo.all(Language)
all_resources = Repo.all(Resource)

IO.puts("  → Found #{length(all_languages)} languages and #{length(all_resources)} resources")

# Sample problem metadata templates by subject and difficulty
problem_templates = [
  # Physics problems
  %{
    subject: "Physics",
    difficulty: "easy",
    meta_data: %{
      "question" => %{
        "text" => "A ball is dropped from a height of 20 m. What is its velocity just before hitting the ground? (g = 10 m/s²)",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "10 m/s"},
          %{"key" => "B", "text" => "20 m/s"},
          %{"key" => "C", "text" => "40 m/s"},
          %{"key" => "D", "text" => "200 m/s"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "Using v² = u² + 2gh, where u=0, g=10, h=20: v = √(2×10×20) = 20 m/s"
      },
      "solution" => %{
        "steps" => [
          "Given: height h = 20 m, initial velocity u = 0, g = 10 m/s²",
          "Using kinematic equation: v² = u² + 2gh",
          "v² = 0² + 2×10×20 = 400",
          "v = √400 = 20 m/s"
        ],
        "difficulty" => "easy",
        "concepts" => ["free fall", "kinematics", "gravity"]
      }
    }
  },
  %{
    subject: "Physics",
    difficulty: "medium",
    meta_data: %{
      "question" => %{
        "text" => "A spring with spring constant 100 N/m is compressed by 0.2 m. What is the elastic potential energy stored?",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "1 J"},
          %{"key" => "B", "text" => "2 J"},
          %{"key" => "C", "text" => "4 J"},
          %{"key" => "D", "text" => "20 J"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "Elastic potential energy = (1/2)kx² = (1/2)×100×(0.2)² = 2 J"
      },
      "solution" => %{
        "steps" => [
          "Given: spring constant k = 100 N/m, compression x = 0.2 m",
          "Formula: Elastic potential energy = (1/2)kx²",
          "U = (1/2)×100×(0.2)²",
          "U = 50×0.04 = 2 J"
        ],
        "difficulty" => "medium",
        "concepts" => ["elastic potential energy", "springs", "energy"]
      }
    }
  },
  # Chemistry problems
  %{
    subject: "Chemistry",
    difficulty: "easy",
    meta_data: %{
      "question" => %{
        "text" => "What is the atomic number of carbon?",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "4"},
          %{"key" => "B", "text" => "6"},
          %{"key" => "C", "text" => "12"},
          %{"key" => "D", "text" => "14"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "Carbon has 6 protons in its nucleus, so its atomic number is 6"
      },
      "solution" => %{
        "steps" => [
          "Atomic number = number of protons in nucleus",
          "Carbon has 6 protons",
          "Therefore, atomic number of carbon = 6"
        ],
        "difficulty" => "easy",
        "concepts" => ["atomic structure", "periodic table", "atomic number"]
      }
    }
  },
  %{
    subject: "Chemistry",
    difficulty: "medium",
    meta_data: %{
      "question" => %{
        "text" => "How many moles of NaCl are present in 117 g of sodium chloride? (Molar mass of NaCl = 58.5 g/mol)",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "1 mol"},
          %{"key" => "B", "text" => "2 mol"},
          %{"key" => "C", "text" => "3 mol"},
          %{"key" => "D", "text" => "4 mol"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "Number of moles = given mass / molar mass = 117 g / 58.5 g/mol = 2 mol"
      },
      "solution" => %{
        "steps" => [
          "Given: mass of NaCl = 117 g, molar mass = 58.5 g/mol",
          "Formula: Number of moles = mass / molar mass",
          "Number of moles = 117 / 58.5 = 2 mol"
        ],
        "difficulty" => "medium",
        "concepts" => ["molar mass", "mole concept", "stoichiometry"]
      }
    }
  },
  # Mathematics problems
  %{
    subject: "Mathematics",
    difficulty: "easy",
    meta_data: %{
      "question" => %{
        "text" => "What is the value of sin 30°?",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "1/2"},
          %{"key" => "B", "text" => "√3/2"},
          %{"key" => "C", "text" => "1"},
          %{"key" => "D", "text" => "√2/2"}
        ]
      },
      "answer" => %{
        "correct_option" => "A",
        "explanation" => "sin 30° = 1/2 is a standard trigonometric value"
      },
      "solution" => %{
        "steps" => [
          "30° is a standard angle in trigonometry",
          "From the 30-60-90 triangle ratios",
          "sin 30° = opposite/hypotenuse = 1/2"
        ],
        "difficulty" => "easy",
        "concepts" => ["trigonometry", "standard angles", "sine function"]
      }
    }
  },
  %{
    subject: "Mathematics",
    difficulty: "medium",
    meta_data: %{
      "question" => %{
        "text" => "Find the derivative of f(x) = 3x² + 2x - 5",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "6x + 2"},
          %{"key" => "B", "text" => "3x + 2"},
          %{"key" => "C", "text" => "6x - 5"},
          %{"key" => "D", "text" => "3x² + 2"}
        ]
      },
      "answer" => %{
        "correct_option" => "A",
        "explanation" => "Using power rule: d/dx(3x²) = 6x, d/dx(2x) = 2, d/dx(-5) = 0, so f'(x) = 6x + 2"
      },
      "solution" => %{
        "steps" => [
          "Given: f(x) = 3x² + 2x - 5",
          "Apply power rule: d/dx(xⁿ) = nxⁿ⁻¹",
          "d/dx(3x²) = 3×2x = 6x",
          "d/dx(2x) = 2",
          "d/dx(-5) = 0",
          "Therefore: f'(x) = 6x + 2"
        ],
        "difficulty" => "medium",
        "concepts" => ["calculus", "derivatives", "power rule"]
      }
    }
  },
  # Biology problems
  %{
    subject: "Biology",
    difficulty: "easy",
    meta_data: %{
      "question" => %{
        "text" => "Which gas do plants absorb from the atmosphere during photosynthesis?",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "Oxygen"},
          %{"key" => "B", "text" => "Carbon dioxide"},
          %{"key" => "C", "text" => "Nitrogen"},
          %{"key" => "D", "text" => "Hydrogen"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "Plants absorb carbon dioxide (CO₂) from the atmosphere during photosynthesis and release oxygen"
      },
      "solution" => %{
        "steps" => [
          "Photosynthesis equation: 6CO₂ + 6H₂O + light → C₆H₁₂O₆ + 6O₂",
          "Plants use carbon dioxide as raw material",
          "They release oxygen as a byproduct",
          "Therefore, plants absorb CO₂ during photosynthesis"
        ],
        "difficulty" => "easy",
        "concepts" => ["photosynthesis", "plant biology", "gas exchange"]
      }
    }
  },
  %{
    subject: "Biology",
    difficulty: "medium",
    meta_data: %{
      "question" => %{
        "text" => "In which phase of mitosis do chromosomes align at the cell's equator?",
        "type" => "mcq",
        "options" => [
          %{"key" => "A", "text" => "Prophase"},
          %{"key" => "B", "text" => "Metaphase"},
          %{"key" => "C", "text" => "Anaphase"},
          %{"key" => "D", "text" => "Telophase"}
        ]
      },
      "answer" => %{
        "correct_option" => "B",
        "explanation" => "During metaphase, chromosomes align at the cell's equator (metaphase plate) before separation"
      },
      "solution" => %{
        "steps" => [
          "Mitosis has four main phases: prophase, metaphase, anaphase, telophase",
          "In metaphase, spindle fibers attach to kinetochores",
          "Chromosomes move to and align at the cell's equator",
          "This alignment is called the metaphase plate",
          "After alignment, chromosomes separate in anaphase"
        ],
        "difficulty" => "medium",
        "concepts" => ["cell division", "mitosis", "chromosome behavior"]
      }
    }
  }
]

# Function to randomly select problem template and customize it
get_random_problem_data = fn ->
  template = Enum.random(problem_templates)

  # Add some randomization to make each problem unique
  base_meta = template.meta_data

  # Vary the question slightly with additional context
  variations = [
    "Calculate the following:",
    "Determine the value:",
    "Find the answer:",
    "What is the result?"
  ]

  question_prefix = if :rand.uniform(10) > 7, do: "#{Enum.random(variations)} ", else: ""

  updated_meta = put_in(base_meta, ["question", "text"],
    question_prefix <> base_meta["question"]["text"])

  %{template | meta_data: updated_meta}
end

# Get existing problem_lang combinations to avoid duplicates
existing_combinations =
  from(pl in ProblemLanguage, select: {pl.res_id, pl.lang_id})
  |> Repo.all()
  |> MapSet.new()

# Generate random resource-language combinations that don't exist
target_count = min(50, length(all_resources) * length(all_languages))
combinations_to_create = []

combinations_to_create =
  for _i <- 1..target_count, reduce: [] do
    acc ->
      if length(acc) >= target_count do
        acc
      else
        resource = Enum.random(all_resources)
        language = Enum.random(all_languages)
        combination = {resource.id, language.id}

        if combination in existing_combinations or
           Enum.any?(acc, fn {r_id, l_id, _} -> r_id == resource.id and l_id == language.id end) do
          acc
        else
          problem_data = get_random_problem_data.()
          [{resource.id, language.id, problem_data.meta_data} | acc]
        end
      end
  end

IO.puts("  → Will create #{length(combinations_to_create)} new problem language records")

# Create problem language records
problem_langs_created =
  for {res_id, lang_id, meta_data} <- combinations_to_create do
    attrs = %{
      res_id: res_id,
      lang_id: lang_id,
      meta_data: meta_data
    }

    case %ProblemLanguage{} |> ProblemLanguage.changeset(attrs) |> Repo.insert() do
      {:ok, _} -> 1
      {:error, changeset} ->
        IO.puts("  ⚠️  Failed to create problem language: #{inspect(changeset.errors)}")
        0
    end
  end
  |> Enum.sum()

IO.puts("  ✅ Created #{problem_langs_created} problem language records")
