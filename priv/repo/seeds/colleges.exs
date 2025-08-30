alias Dbservice.Repo

IO.puts("  → Seeding colleges...")

# College data for NITs and IITs
colleges_data = [
  # IITs
  %{
    college_id: "IIT001",
    name: "Indian Institute of Technology, Bombay",
    state: "Maharashtra",
    address: "Powai, Mumbai",
    district: "Mumbai",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1958,
    affiliated_to: "Autonomous",
    tuition_fee: Decimal.new("200000"),
    af_hierarchy: Decimal.new("1.0"),
    expected_salary: Decimal.new("1500000"),
    salary_tier: "Tier 1",
    qualifying_exam: "JEE Advanced",
    nirf_ranking: 1,
    top_200_nirf: true
  },
  %{
    college_id: "IIT002",
    name: "Indian Institute of Technology, Delhi",
    state: "Delhi",
    address: "Hauz Khas, New Delhi",
    district: "New Delhi",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1961,
    affiliated_to: "Autonomous",
    tuition_fee: Decimal.new("200000"),
    af_hierarchy: Decimal.new("1.0"),
    expected_salary: Decimal.new("1400000"),
    salary_tier: "Tier 1",
    qualifying_exam: "JEE Advanced",
    nirf_ranking: 2,
    top_200_nirf: true
  },
  %{
    college_id: "IIT003",
    name: "Indian Institute of Technology, Madras",
    state: "Tamil Nadu",
    address: "Sardar Patel Road, Chennai",
    district: "Chennai",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1959,
    affiliated_to: "Autonomous",
    tuition_fee: Decimal.new("200000"),
    af_hierarchy: Decimal.new("1.0"),
    expected_salary: Decimal.new("1350000"),
    salary_tier: "Tier 1",
    qualifying_exam: "JEE Advanced",
    nirf_ranking: 3,
    top_200_nirf: true
  },
  %{
    college_id: "IIT004",
    name: "Indian Institute of Technology, Kanpur",
    state: "Uttar Pradesh",
    address: "Kalyanpur, Kanpur",
    district: "Kanpur",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1959,
    affiliated_to: "Autonomous",
    tuition_fee: Decimal.new("200000"),
    af_hierarchy: Decimal.new("1.0"),
    expected_salary: Decimal.new("1300000"),
    salary_tier: "Tier 1",
    qualifying_exam: "JEE Advanced",
    nirf_ranking: 4,
    top_200_nirf: true
  },
  %{
    college_id: "IIT005",
    name: "Indian Institute of Technology, Kharagpur",
    state: "West Bengal",
    address: "Kharagpur",
    district: "West Midnapore",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1951,
    affiliated_to: "Autonomous",
    tuition_fee: Decimal.new("200000"),
    af_hierarchy: Decimal.new("1.0"),
    expected_salary: Decimal.new("1250000"),
    salary_tier: "Tier 1",
    qualifying_exam: "JEE Advanced",
    nirf_ranking: 5,
    top_200_nirf: true
  },

  # NITs
  %{
    college_id: "NIT001",
    name: "National Institute of Technology, Tiruchirappalli",
    state: "Tamil Nadu",
    address: "Tiruchirappalli",
    district: "Tiruchirappalli",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1964,
    affiliated_to: "NIT Council",
    tuition_fee: Decimal.new("150000"),
    af_hierarchy: Decimal.new("2.0"),
    expected_salary: Decimal.new("800000"),
    salary_tier: "Tier 2",
    qualifying_exam: "JEE Main",
    nirf_ranking: 15,
    top_200_nirf: true
  },
  %{
    college_id: "NIT002",
    name: "National Institute of Technology, Warangal",
    state: "Telangana",
    address: "Warangal",
    district: "Warangal",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1959,
    affiliated_to: "NIT Council",
    tuition_fee: Decimal.new("150000"),
    af_hierarchy: Decimal.new("2.0"),
    expected_salary: Decimal.new("750000"),
    salary_tier: "Tier 2",
    qualifying_exam: "JEE Main",
    nirf_ranking: 18,
    top_200_nirf: true
  },
  %{
    college_id: "NIT003",
    name: "National Institute of Technology, Surathkal",
    state: "Karnataka",
    address: "Surathkal, Mangalore",
    district: "Dakshina Kannada",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1960,
    affiliated_to: "NIT Council",
    tuition_fee: Decimal.new("150000"),
    af_hierarchy: Decimal.new("2.0"),
    expected_salary: Decimal.new("700000"),
    salary_tier: "Tier 2",
    qualifying_exam: "JEE Main",
    nirf_ranking: 25,
    top_200_nirf: true
  },
  %{
    college_id: "NIT004",
    name: "National Institute of Technology, Rourkela",
    state: "Odisha",
    address: "Rourkela",
    district: "Sundargarh",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1961,
    affiliated_to: "NIT Council",
    tuition_fee: Decimal.new("150000"),
    af_hierarchy: Decimal.new("2.0"),
    expected_salary: Decimal.new("650000"),
    salary_tier: "Tier 2",
    qualifying_exam: "JEE Main",
    nirf_ranking: 30,
    top_200_nirf: true
  },
  %{
    college_id: "NIT005",
    name: "National Institute of Technology, Calicut",
    state: "Kerala",
    address: "Calicut",
    district: "Kozhikode",
    gender_type: "Co-Ed",
    college_type: "Engineering",
    management_type: "Government",
    year_established: 1961,
    affiliated_to: "NIT Council",
    tuition_fee: Decimal.new("150000"),
    af_hierarchy: Decimal.new("2.0"),
    expected_salary: Decimal.new("600000"),
    salary_tier: "Tier 2",
    qualifying_exam: "JEE Main",
    nirf_ranking: 35,
    top_200_nirf: true
  }
]

colleges_created =
  for college_data <- colleges_data do
    # Check if college already exists by college_id
    existing_college = Repo.get_by(Dbservice.Colleges.College, college_id: college_data.college_id)

    if existing_college do
      0  # Already exists
    else
      case Repo.insert(%Dbservice.Colleges.College{} |> Dbservice.Colleges.College.changeset(college_data)) do
        {:ok, _} -> 1
        {:error, _} -> 0
      end
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Created #{colleges_created} colleges")
