alias Dbservice.Repo
alias Dbservice.Schools.School

IO.puts("→ Seeding schools...")

# Generate 20 schools with random data
school_categories = ["GBSSS", "GIC", "GHS", "GSSS", "GGHSS", "GGSS", "GHSS", "GPS", "GMS", "GUPS"]
gender_types = ["Girls", "Boys"]
boards = ["CBSE", "ICSE"]
regions = ["North", "South", "East", "West", "Central"]

indian_states = [
  "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat",
  "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh",
  "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab",
  "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh",
  "Uttarakhand", "West Bengal"
]

# Generate 20 unique school codes efficiently
school_codes = Enum.map(1..20, fn _ ->
  # Generate a random 10-digit number
  Enum.random(1000000000..9999999999) |> to_string()
end)
|> Enum.uniq()
|> case do
  codes when length(codes) < 20 ->
    # If we have duplicates, generate more codes to reach 20
    additional_needed = 20 - length(codes)
    additional_codes = Stream.repeatedly(fn ->
      Enum.random(1000000000..9999999999) |> to_string()
    end)
    |> Stream.reject(&(&1 in codes))
    |> Enum.take(additional_needed)

    codes ++ additional_codes
  codes ->
    codes
end

schools_data = for {code, index} <- Enum.with_index(school_codes, 1) do
  state = Enum.random(indian_states)
  category = Enum.random(school_categories)

  %{
    code: code,
    name: "#{category} School #{index}",
    udise_code: code,  # Same as code
    gender_type: Enum.random(gender_types),
    af_school_category: category,
    region: Enum.random(regions),
    state_code: "#{Enum.random(1..29)}",
    state: state,
    district_code: "#{Enum.random(100..999)}",
    district: "District #{Enum.random(1..50)}",
    block_code: if(Enum.random([true, false]), do: "#{Enum.random(100..999)}", else: nil),
    block_name: if(Enum.random([true, false]), do: "Block #{Enum.random(1..20)}", else: nil),
    board: Enum.random(boards),
    user_id: nil
  }
end

schools_created = for school_attrs <- schools_data do
  unless Repo.get_by(School, code: school_attrs.code) do
    %School{}
    |> School.changeset(school_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_schools_created = Enum.count(schools_created, &(&1 != nil))
IO.puts("    ✅ Schools seeded (#{length(schools_data)} total, #{actual_schools_created} new schools)")
