alias Dbservice.Repo
alias Dbservice.SchoolBatches.SchoolBatch
import Ecto.Query

IO.puts("  → Seeding school batches...")

# Fetch actual school IDs and batch IDs from database
school_ids = Repo.all(from s in Dbservice.Schools.School, select: s.id)
batch_ids = Repo.all(from b in Dbservice.Batches.Batch, select: b.id)

# Generate 20 random school-batch associations
school_batch_data = Enum.map(1..20, fn _index ->
  %{
    school_id: Enum.random(school_ids),
    batch_id: Enum.random(batch_ids)
  }
end)

school_batches_created = for school_batch_attrs <- school_batch_data do
  unless Repo.get_by(SchoolBatch, school_id: school_batch_attrs.school_id, batch_id: school_batch_attrs.batch_id) do
    %SchoolBatch{}
    |> SchoolBatch.changeset(school_batch_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_school_batches_created = Enum.count(school_batches_created, &(&1 != nil))
IO.puts("    ✅ School batches seeded (#{length(school_batch_data)} total, #{actual_school_batches_created} new school batches)")
