alias Dbservice.Repo
alias Dbservice.Programs.Program
import Ecto.Query

IO.puts("→ Seeding programs...")

# Fetch actual product IDs from database
product_ids = Repo.all(from p in Dbservice.Products.Product, select: p.id)

programs_data = [
  %{name: "Gujarat Broadcast", state: "Gujarat", model: "Broadcast"},
  %{name: "TN TW (Async)", state: "Tamil Nadu", model: "Async"},
  %{name: "STP Live Class HP", state: "Himachal Pradesh", model: "Live Class"},
  %{name: "TN CoAE Chennai TP (Physical)", state: "Tamil Nadu", model: "Physical"},
  %{name: "TN Model Schools (Async)", state: "Tamil Nadu", model: "Async"},
  %{name: "Gujarat Test Series", state: "Gujarat", model: "Test Series"},
  %{name: "STP Test Series FeedingIndia", state: "Across India", model: "Test Series"},
  %{name: "Delhi G11 Sync", state: "Delhi", model: "Sync"},
  %{name: "STP Test Series CG", state: "Chhattisgarh", model: "Test Series"},
  %{name: "STP Live Class Punjab", state: "Punjab", model: "Live Class"},
  %{name: "TN Teacher Training", state: "Tamil Nadu", model: "Teacher Training"},
  %{name: "EMRS CoE", state: "EMRS", model: "Physical"},
  %{name: "STP Test Series LBF", state: "Across India", model: "Test Series"},
  %{name: "Gurukul - All India", state: "Across India", model: "Gurukul", donor: "Capgemini"}
]

# Generate random product_ids for each program
random_product_ids = Enum.map(1..length(programs_data), fn _ -> Enum.random(product_ids) end)

# Merge product_id and other default fields into each program
programs_data_with_products =
  Enum.zip(programs_data, random_product_ids)
  |> Enum.map(fn {program, product_id} ->
    Map.merge(%{
      target_outreach: nil,
      donor: Map.get(program, :donor, nil),
      product_id: product_id,
      is_current: true
    }, program)
  end)

programs_created = for program_attrs <- programs_data_with_products do
  unless Repo.get_by(Program, name: program_attrs.name) do
    %Program{}
    |> Program.changeset(program_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_programs_created = Enum.count(programs_created, &(&1 != nil))
IO.puts("    ✅ Programs seeded (#{length(programs_data)} total, #{actual_programs_created} new programs)")
