alias Dbservice.Repo
alias Dbservice.Batches.Batch
import Ecto.Query

IO.puts("  → Seeding batches...")

auth_group_ids = Repo.all(from ag in Dbservice.Groups.AuthGroup, select: ag.id)
program_ids = Repo.all(from p in Dbservice.Programs.Program, select: p.id)

get_random_ids = fn ->
  %{
    program_id: Enum.random(program_ids),
    auth_group_id: Enum.random(auth_group_ids)
  }
end

batches_data = [
  %{
    name: "Gujarat TestSeries G11 PCMB",
    contact_hours_per_week: nil,
    batch_id: "GujaratStudents_11_Photon_PCMB_25_B001",
    parent_id: nil,
    start_date: ~D[2025-06-25],
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "Delhi 10 Quiz Batch - 24",
    contact_hours_per_week: nil,
    batch_id: "DL-10-Foundation-24",
    parent_id: nil,
    start_date: ~D[2024-09-19],
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "COE JNV Adilabad Grade 12 Medical",
    contact_hours_per_week: nil,
    batch_id: "EnableStudents_12_Alpha_med_24_C004",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "SOSE, Andrews Ganj",
    contact_hours_per_week: nil,
    batch_id: "DelhiStudents_11_Photon_Eng_24_S029",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "Nodal JNV Hassan Grade 12 Medical",
    contact_hours_per_week: nil,
    batch_id: "EnableStudents_12_Photon_med_24_N006",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "UK 12 Selection Batch",
    contact_hours_per_week: nil,
    batch_id: "UK-12-Selection-24",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "12M01",
    contact_hours_per_week: nil,
    batch_id: "UttarakhandStudents_12_Photon_Eng_25_L001",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  },
  %{
    name: "Parinaam G11 Medical",
    contact_hours_per_week: nil,
    batch_id: "TNStudents_11_Photon_med_24_S002",
    parent_id: nil,
    start_date: nil,
    end_date: nil,
    af_medium: nil
  }
]

batches_data =
  Enum.map(batches_data, fn batch ->
    Map.merge(batch, get_random_ids.())
  end)

batches_created = for batch_attrs <- batches_data do
  unless Repo.get_by(Batch, batch_id: batch_attrs.batch_id) do
    %Batch{}
    |> Batch.changeset(batch_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_batches_created = Enum.count(batches_created, &(&1 != nil))
IO.puts("    ✅ Batches seeded (#{length(batches_data)} total, #{actual_batches_created} new batches)")
