alias Dbservice.Repo
alias Dbservice.Batches.Batch
import Ecto.Query

IO.puts("→ Seeding batches...")

auth_group_ids = Repo.all(from ag in Dbservice.Groups.AuthGroup, select: ag.id)
program_ids = Repo.all(from p in Dbservice.Programs.Program, select: p.id)

get_random_ids = fn ->
  %{
    program_id: Enum.random(program_ids),
    auth_group_id: Enum.random(auth_group_ids)
  }
end

# First, seed parent batches
parent_batches_data = [
  %{
    name: "Gujarat TestSeries G11 PCMB",
    batch_id: "GujaratStudents_11_Photon_PCMB_25_B001",
    start_date: ~D[2025-06-25]
  },
  %{
    name: "Delhi 10 Quiz Batch - 24",
    batch_id: "DL-10-Foundation-24",
    start_date: ~D[2024-09-19]
  },
  %{
    name: "COE JNV Adilabad Grade 12 Medical",
    batch_id: "EnableStudents_12_Alpha_med_24_C004"
  },
  %{
    name: "UK 12 Selection Batch",
    batch_id: "UK-12-Selection-24"
  }
]

# Seed parent batches first
parent_batches_data =
  Enum.map(parent_batches_data, fn batch ->
    Map.merge(batch, get_random_ids.())
  end)

parent_batches_created = for batch_attrs <- parent_batches_data do
  existing_batch = Repo.get_by(Batch, batch_id: batch_attrs.batch_id)
  unless existing_batch do
    %Batch{}
    |> Batch.changeset(batch_attrs)
    |> Repo.insert!()
  else
    existing_batch
  end
end

# Get parent batch IDs for child batches
gujarat_parent_id = Enum.find(parent_batches_created, &(&1.batch_id == "GujaratStudents_11_Photon_PCMB_25_B001")).id
delhi_parent_id = Enum.find(parent_batches_created, &(&1.batch_id == "DL-10-Foundation-24")).id
coe_parent_id = Enum.find(parent_batches_created, &(&1.batch_id == "EnableStudents_12_Alpha_med_24_C004")).id
uk_parent_id = Enum.find(parent_batches_created, &(&1.batch_id == "UK-12-Selection-24")).id

# Now seed child batches with parent references
child_batches_data = [
  %{
    name: "SOSE, Andrews Ganj",
    batch_id: "DelhiStudents_11_Photon_Eng_24_S029",
    parent_id: delhi_parent_id
  },
  %{
    name: "Nodal JNV Hassan Grade 12 Medical",
    batch_id: "EnableStudents_12_Photon_med_24_N006",
    parent_id: coe_parent_id
  },
  %{
    name: "12M01",
    batch_id: "UttarakhandStudents_12_Photon_Eng_25_L001",
    parent_id: uk_parent_id
  },
  %{
    name: "Parinaam G11 Medical",
    batch_id: "TNStudents_11_Photon_med_24_S002",
    parent_id: gujarat_parent_id
  }
]

# Combine all batches for final processing
batches_data = parent_batches_data ++ child_batches_data

# Add random IDs to child batches only (parent batches already have them)
child_batches_data =
  Enum.map(child_batches_data, fn batch ->
    Map.merge(batch, get_random_ids.())
  end)

# Seed child batches
child_batches_created = for batch_attrs <- child_batches_data do
  unless Repo.get_by(Batch, batch_id: batch_attrs.batch_id) do
    %Batch{}
    |> Batch.changeset(batch_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

total_batches = length(parent_batches_data) + length(child_batches_data)
new_parent_batches = Enum.count(parent_batches_created, &(&1.id != nil and Repo.get_by(Batch, id: &1.id)))
new_child_batches = Enum.count(child_batches_created, &(&1 != nil))
total_new_batches = new_child_batches + Enum.count(parent_batches_data, fn batch ->
  not is_nil(Repo.get_by(Batch, batch_id: batch.batch_id))
end)

IO.puts("    ✅ Batches seeded (#{total_batches} total, parent-child relationships established)")
IO.puts("    📊 Created #{new_child_batches} new child batches with parent references")
