import Ecto.Query
alias Dbservice.Repo

# Fetch all necessary entities for relationships
purposes = Repo.all(from p in "purpose", select: p.id)
tags = Repo.all(from t in "tag", select: t.id)
skills = Repo.all(from s in "skill", select: s.id)
learning_objectives = Repo.all(from lo in "learning_objective", select: lo.id)
exams = Repo.all(from e in "exam", select: e.id)
teachers = Repo.all(from t in "teacher", select: t.id)

IO.puts("Found #{length(purposes)} purposes, #{length(tags)} tags, #{length(skills)} skills")
IO.puts("Found #{length(learning_objectives)} learning objectives, #{length(exams)} exams, #{length(teachers)} teachers")

# Educational topics for different subjects
physics_topics = [
  "Newton's Laws of Motion", "Gravitation", "Friction", "Elasticity and Viscosity",
  "Calorimetry and Thermal Expansion", "Heat Transfer", "Rigid Body Dynamics",
  "Units and Dimensions", "Electromagnetic Waves", "Geometrical Optics",
  "Semiconductor", "Wave Optics", "Modern Physics"
]

chemistry_topics = [
  "Redox Reaction", "Ionic Equilibrium", "Alcohols, Phenols and Ethers",
  "Hydrocarbons", "Aldehydes, Ketones, Carboxylic Acids", "Chemical Bonding",
  "Periodic Table", "Coordination Compounds", "Organic Chemistry",
  "Electrochemistry", "Surface Chemistry", "Nuclear Chemistry"
]

biology_topics = [
  "The Living World", "Biological Classification", "Plant Kingdom",
  "Morphology of Flowering Plants", "Microbes In Human Welfare",
  "Biomolecules", "Cell Structure and Function", "Genetics",
  "Evolution", "Ecology", "Human Physiology", "Plant Physiology"
]

math_topics = [
  "Mathematical Tools", "Permutation and Combination", "Trigonometry",
  "Circle", "Fundamentals Of Mathematics", "Sets, Relations and Functions",
  "Sequence and Series", "Calculus", "Coordinate Geometry",
  "Matrices and Determinants", "Statistics", "Probability"
]

law_topics = [
  "Law of Crimes", "Constitutional Law", "Contract Law", "Criminal Procedure",
  "Civil Procedure", "Evidence Law", "Property Law", "Administrative Law",
  "International Law", "Human Rights", "Corporate Law", "Environmental Law"
]

all_topics = physics_topics ++ chemistry_topics ++ biology_topics ++ math_topics ++ law_topics

# Resource types and their configurations
resource_types = [
  %{
    type: "document",
    subtype: "Module",
    code_prefix: "M",
    source: "gdrive",
    type_params: fn topic -> %{
      "src_link" => "https://drive.google.com/file/d/#{String.replace(topic, " ", "")}#{:rand.uniform(999999)}/view?usp=drive_link"
    } end
  },
  %{
    type: "video",
    subtype: "Video Lectures",
    code_prefix: "V",
    source: "youtube",
    type_params: fn topic -> %{
      "src_link" => "https://www.youtube.com/playlist?list=PLazkD3nUYns#{String.slice(topic, 0, 10)}#{:rand.uniform(999999)}"
    } end
  },
  %{
    type: "quiz",
    subtype: "Assessment",
    code_prefix: "Q",
    source: nil,
    type_params: fn _topic -> %{
      "src_link" => "https://quiz.avantifellows.org/quiz/#{:rand.uniform(999999999999999)}?apiKey=6qOO8UdF1EGxLgzwIbQN&userId=test_admin"
    } end
  },
  %{
    type: "document",
    subtype: "Previous Year Questions",
    code_prefix: "PYQ",
    source: "gdrive",
    type_params: fn topic -> %{
      "src_link" => "https://drive.google.com/file/d/#{String.replace(topic, " ", "")}PYQ#{:rand.uniform(999999)}/view?usp=drive_link"
    } end
  }
]

# CMS statuses
cms_statuses = ["archived", "draft", "review", "final"]

# Helper function to generate resource name with multiple languages
generate_resource_name = fn topic ->
  # Create Hindi translations for common educational terms
  hindi_translations = %{
    "Newton's Laws of Motion" => "न्यूटन के गति नियम",
    "Gravitation" => "गुरुत्वाकर्षण",
    "Friction" => "घर्षण",
    "Heat Transfer" => "ऊष्मा स्थानांतरण",
    "Redox Reaction" => "अपचयोपचय अभिक्रिया",
    "Ionic Equilibrium" => "आयनिक साम्यावस्था",
    "Chemical Bonding" => "रासायनिक बंधन",
    "The Living World" => "जैविक जगत",
    "Plant Kingdom" => "पादप जगत",
    "Mathematical Tools" => "गणितीय उपकरण",
    "Trigonometry" => "त्रिकोणमिति",
    "Calculus" => "कलन",
    "Law of Crimes" => "अपराध विधि",
    "Constitutional Law" => "संवैधानिक कानून",
    "Contract Law" => "संविदा कानून"
  }

  hindi_name = Map.get(hindi_translations, topic, "#{topic} (हिंदी)")

  [
    %{"resource" => topic, "lang_code" => "en"},
    %{"resource" => hindi_name, "lang_code" => "hi"}
  ]
end

# Helper function to randomly select array elements
random_select = fn list, min_count, max_count ->
  if length(list) == 0 do
    []
  else
    count = min(:rand.uniform(max_count - min_count + 1) + min_count - 1, length(list))
    Enum.take_random(list, count)
  end
end

# Generate resources
resources = for i <- 1..100 do
  topic = Enum.random(all_topics)
  resource_config = Enum.random(resource_types)

  # Generate relationships
  purpose_ids = if length(purposes) > 0, do: random_select.(purposes, 1, 3), else: nil
  tag_ids = if length(tags) > 0, do: random_select.(tags, 0, 2), else: nil
  skill_ids = if length(skills) > 0, do: random_select.(skills, 0, 3), else: nil
  learning_objective_ids = if length(learning_objectives) > 0, do: random_select.(learning_objectives, 0, 2), else: nil
  exam_ids = if length(exams) > 0, do: random_select.(exams, 0, 2), else: nil
  teacher_id = if length(teachers) > 0, do: Enum.random(teachers), else: nil

  # Convert empty arrays to nil for database constraints
  purpose_ids = if purpose_ids && length(purpose_ids) > 0, do: purpose_ids, else: nil
  tag_ids = if tag_ids && length(tag_ids) > 0, do: tag_ids, else: nil
  skill_ids = if skill_ids && length(skill_ids) > 0, do: skill_ids, else: nil
  learning_objective_ids = if learning_objective_ids && length(learning_objective_ids) > 0, do: learning_objective_ids, else: nil
  exam_ids = if exam_ids && length(exam_ids) > 0, do: exam_ids, else: nil

  %{
    type: resource_config.type,
    type_params: resource_config.type_params.(topic),
    subtype: resource_config.subtype,
    code: "#{resource_config.code_prefix}-#{1000 + i}",
    name: generate_resource_name.(topic),
    source: resource_config.source,
    purpose_ids: purpose_ids,
    tag_ids: tag_ids,
    skill_ids: skill_ids,
    learning_objective_ids: learning_objective_ids,
    exam_ids: exam_ids,
    teacher_id: teacher_id,
    cms_status: Enum.random(cms_statuses),
    inserted_at: DateTime.utc_now() |> DateTime.truncate(:second),
    updated_at: DateTime.utc_now() |> DateTime.truncate(:second)
  }
end

# Insert resources in batches
batch_size = 50
total_batches = ceil(length(resources) / batch_size)

Enum.chunk_every(resources, batch_size)
|> Enum.with_index(1)
|> Enum.each(fn {batch, batch_num} ->
  IO.puts("Inserting resource batch #{batch_num}/#{total_batches}...")

  try do
    {count, _} = Repo.insert_all("resource", batch)
    IO.puts("Successfully inserted #{count} resources in batch #{batch_num}")
  rescue
    e ->
      IO.puts("Error inserting resource batch #{batch_num}: #{inspect(e)}")

      # Try individual inserts for this batch
      IO.puts("Attempting individual inserts for batch #{batch_num}...")

      Enum.each(batch, fn resource ->
        try do
          Repo.insert_all("resource", [resource])
        rescue
          individual_error ->
            IO.puts("Failed to insert individual resource: #{inspect(individual_error)}")
            IO.puts("Resource data: #{inspect(resource)}")
        end
      end)
  end
end)

IO.puts("Resource seeding completed!")

# Verify the results
resource_count = Repo.aggregate(from(r in "resource"), :count, :id)
resources_with_purposes = Repo.aggregate(from(r in "resource", where: not is_nil(r.purpose_ids)), :count, :id)
resources_with_tags = Repo.aggregate(from(r in "resource", where: not is_nil(r.tag_ids)), :count, :id)
resources_with_skills = Repo.aggregate(from(r in "resource", where: not is_nil(r.skill_ids)), :count, :id)
resources_with_learning_objectives = Repo.aggregate(from(r in "resource", where: not is_nil(r.learning_objective_ids)), :count, :id)
resources_with_exams = Repo.aggregate(from(r in "resource", where: not is_nil(r.exam_ids)), :count, :id)
resources_with_teachers = Repo.aggregate(from(r in "resource", where: not is_nil(r.teacher_id)), :count, :id)

IO.puts("\n=== Resource Seeding Summary ===")
IO.puts("Total resources created: #{resource_count}")
IO.puts("Resources with purposes: #{resources_with_purposes}")
IO.puts("Resources with tags: #{resources_with_tags}")
IO.puts("Resources with skills: #{resources_with_skills}")
IO.puts("Resources with learning objectives: #{resources_with_learning_objectives}")
IO.puts("Resources with exams: #{resources_with_exams}")
IO.puts("Resources with teachers: #{resources_with_teachers}")

# Show distribution by type
type_distribution = Repo.all(from(r in "resource", group_by: r.type, select: {r.type, count(r.id)}))
IO.puts("\nResource type distribution:")
Enum.each(type_distribution, fn {type, count} ->
  IO.puts("  #{type}: #{count}")
end)

# Show distribution by CMS status
cms_distribution = Repo.all(from(r in "resource", group_by: r.cms_status, select: {r.cms_status, count(r.id)}))
IO.puts("\nCMS status distribution:")
Enum.each(cms_distribution, fn {status, count} ->
  IO.puts("  #{status}: #{count}")
end)
