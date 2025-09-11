alias Dbservice.Repo
alias Dbservice.Statuses.Status

IO.puts("→ Seeding status...")

status_data = [
  %{
    title: :registered
  },
  %{
    title: :enrolled
  },
  %{
    title: :dropout
  }
]

status_created = for status_attrs <- status_data do
  unless Repo.get_by(Status, title: status_attrs.title) do
    %Status{}
    |> Status.changeset(status_attrs)
    |> Repo.insert!()
  else
    nil
  end
end

actual_status_created = Enum.count(status_created, &(&1 != nil))
IO.puts("    ✅ Status seeded (#{length(status_data)} total, #{actual_status_created} new status)")
