alias Dbservice.Repo
alias Dbservice.Groups.AuthGroup

IO.puts("  → Seeding auth groups...")

# Auth group data - creating auth groups for all Indian states
# Each state will have both teacher and student auth groups
indian_states = [
  "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat",
  "Haryana", "Jharkhand", "Karnataka", "Kerala",
  "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
  "Rajasthan", "Sikkim", "Telangana", "Tripura",
  "Uttarakhand"
]

# Common input schema for students
student_input_schema = %{
  "images" => "https://cdn.avantifellows.org/af_logos/avanti_logo_black_text.webp",
  "auth_type" => "ID,DOB",
  "user_type" => "student",
  "default_locale" => "en"
}

# Common locale data for students
student_locale_data = %{
  "en" => %{
    "ID" => %{
      "key" => "student_id",
      "label" => "Enter your Student ID",
      "required" => true,
      "placeholder" => "Your Student ID"
    },
    "PH" => %{
      "key" => "phone",
      "label" => "Enter your phone number",
      "required" => true,
      "placeholder" => "Your phone number"
    },
    "DOB" => %{
      "key" => "date_of_birth",
      "label" => "Enter your date of birth",
      "required" => true
    }
  }
}

# Common input schema for teachers
teacher_input_schema = %{
  "images" => "https://cdn.avantifellows.org/af_logos/avanti_logo_black_text.webp",
  "auth_type" => "ID",
  "user_type" => "teacher",
  "default_locale" => "en"
}

# Common locale data for teachers
teacher_locale_data = %{
  "en" => %{
    "ID" => %{
      "key" => "teacher_id",
      "label" => "Enter your ID",
      "required" => true,
      "placeholder" => "Your ID",
      "maxLengthOfEntry" => 15
    }
  }
}

# Generate auth groups for all states
auth_groups_data = Enum.flat_map(indian_states, fn state ->
  state_name = String.replace(state, " ", "")  # Remove spaces for auth group name
  [
    # Student auth group for this state
    %{
      name: "#{state_name}Students",
      input_schema: student_input_schema,
      locale: "English",
      locale_data: student_locale_data
    },
    # Teacher auth group for this state
    %{
      name: "#{state_name}Teachers",
      input_schema: teacher_input_schema,
      locale: "English",
      locale_data: teacher_locale_data
    }
  ]
end)

auth_groups_created = for auth_group_attrs <- auth_groups_data do
  unless Repo.get_by(AuthGroup, name: auth_group_attrs.name) do
    %AuthGroup{}
    |> AuthGroup.changeset(auth_group_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_auth_groups_created = Enum.count(auth_groups_created, &(&1 != nil))
IO.puts("✅ Auth groups seeded (#{length(auth_groups_data)} total, #{actual_auth_groups_created} new auth groups)")
