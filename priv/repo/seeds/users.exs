alias Dbservice.Repo
alias Dbservice.Users.User
alias Dbservice.Profiles.UserProfile

IO.puts("  → Seeding users...")

defmodule UserSeeder do
  def create_user_with_role(role, email) do
    state_cities = %{
      "Andhra Pradesh" => ["Visakhapatnam", "Vijayawada", "Guntur"],
      "Arunachal Pradesh" => ["Itanagar", "Naharlagun"],
      "Assam" => ["Guwahati", "Silchar", "Dibrugarh"],
      "Bihar" => ["Patna", "Gaya", "Bhagalpur"],
      "Chhattisgarh" => ["Raipur", "Bhilai", "Bilaspur"],
      "Goa" => ["Panaji", "Margao"],
      "Gujarat" => ["Ahmedabad", "Surat", "Vadodara"],
      "Haryana" => ["Gurgaon", "Faridabad", "Panipat"],
      "Himachal Pradesh" => ["Shimla", "Manali"],
      "Jharkhand" => ["Ranchi", "Jamshedpur", "Dhanbad"],
      "Karnataka" => ["Bengaluru", "Mysuru", "Mangaluru"],
      "Kerala" => ["Thiruvananthapuram", "Kochi", "Kozhikode"],
      "Madhya Pradesh" => ["Bhopal", "Indore", "Gwalior"],
      "Maharashtra" => ["Mumbai", "Pune", "Nagpur"],
      "Manipur" => ["Imphal"],
      "Meghalaya" => ["Shillong"],
      "Mizoram" => ["Aizawl"],
      "Nagaland" => ["Kohima", "Dimapur"],
      "Odisha" => ["Bhubaneswar", "Cuttack", "Rourkela"],
      "Punjab" => ["Ludhiana", "Amritsar", "Jalandhar"],
      "Rajasthan" => ["Jaipur", "Jodhpur", "Udaipur"],
      "Sikkim" => ["Gangtok"],
      "Tamil Nadu" => ["Chennai", "Coimbatore", "Madurai"],
      "Telangana" => ["Hyderabad", "Warangal"],
      "Tripura" => ["Agartala"],
      "Uttar Pradesh" => ["Lucknow", "Kanpur", "Varanasi"],
      "Uttarakhand" => ["Dehradun", "Haridwar"],
      "West Bengal" => ["Kolkata", "Howrah", "Durgapur"]
    }

    genders = ["Male", "Female", "Others"]

    state = Enum.random(Map.keys(state_cities))
    city = Enum.random(Map.get(state_cities, state))

    user_attrs = %{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      email: email,
      phone: "#{Enum.random(7000000000..9999999999)}",
      role: role,
      gender: Enum.random(genders),
      country: "India",
      state: state,
      city: city,
      address: Faker.Address.street_address(),
      district: city,
      pincode: "#{Enum.random(100000..999999)}",
      region: Enum.random(["North", "South", "East", "West", "Central"])
    }

    # Check if user already exists, if not create
    case Repo.get_by(User, email: user_attrs.email) do
      nil ->
        user = %User{}
        |> User.changeset(user_attrs)
        |> Repo.insert!()

        # Create UserProfile for the new user
        %UserProfile{}
        |> UserProfile.changeset(%{
          user_id: user.id,
          logged_in_atleast_once: false,
          latest_session_accessed: nil
        })
        |> Repo.insert!()

        user
      existing_user ->
        existing_user
    end
  end
end

IO.puts("    ✅ User helper functions loaded")
IO.puts("    ℹ️  Users will be created when seeding students, teachers, and candidates")
