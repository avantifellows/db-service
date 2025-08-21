alias Dbservice.Repo
alias Dbservice.Users.User

IO.puts("  → Seeding users...")

# Helper function to create a user with specific role and email
defmodule UserSeeder do
  def create_user_with_role(role, email) do
    indian_states = [
      "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh",
      "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka",
      "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram",
      "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu",
      "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
    ]

    genders = ["Male", "Female", "Others"]

    user_attrs = %{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      email: email,
      phone: "#{Enum.random(7000000000..9999999999)}",
      role: role,
      gender: Enum.random(genders),
      country: "India",
      state: Enum.random(indian_states),
      city: Faker.Address.city(),
      address: Faker.Address.street_address(),
      district: Faker.Address.secondary_address(),
      pincode: "#{Enum.random(100000..999999)}",
      region: Enum.random(["North", "South", "East", "West", "Central"])
    }

    # Check if user already exists, if not create
    case Repo.get_by(User, email: user_attrs.email) do
      nil ->
        %User{}
        |> User.changeset(user_attrs)
        |> Repo.insert!()
      existing_user ->
        existing_user
    end
  end
end

IO.puts("    ✅ User helper functions loaded")
IO.puts("    ℹ️  Users will be created when seeding students, teachers, and candidates")
