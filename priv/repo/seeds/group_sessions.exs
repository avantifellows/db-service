alias Dbservice.Repo
alias Dbservice.Groups.GroupSession
alias Dbservice.Sessions.Session
alias Dbservice.Groups.Group

IO.puts("→ Seeding group sessions...")

# Get all sessions and groups
sessions = Repo.all(Session)
groups = Repo.all(Group)

# Filter groups by type for realistic associations
batch_groups = Enum.filter(groups, &(&1.type == "batch"))
auth_groups = Enum.filter(groups, &(&1.type == "auth_group"))
school_groups = Enum.filter(groups, &(&1.type == "school"))

# Associate each session with random groups
group_sessions_created =
  for session <- sessions do
    selected_groups = []

    # Take up to 5 random batch groups
    selected_groups =
      if length(batch_groups) > 0 do
        Enum.take_random(batch_groups, min(5, length(batch_groups))) ++ selected_groups
      else
        selected_groups
      end

    # Take up to 5 random auth groups
    selected_groups =
      if length(auth_groups) > 0 do
        Enum.take_random(auth_groups, min(5, length(auth_groups))) ++ selected_groups
      else
        selected_groups
      end

    # Take up to 5 random school groups
    selected_groups =
      if length(school_groups) > 0 do
        Enum.take_random(school_groups, min(5, length(school_groups))) ++ selected_groups
      else
        selected_groups
      end

    # Remove duplicates (in case of overlap, though unlikely)
    selected_groups = Enum.uniq_by(selected_groups, & &1.id)

    # Create group_session records for selected groups
    for group <- selected_groups do
      unless Repo.get_by(GroupSession, group_id: group.id, session_id: session.id) do
        %GroupSession{}
        |> GroupSession.changeset(%{
          group_id: group.id,
          session_id: session.id
        })
        |> Repo.insert!()
        1
      else
        0
      end
    end
  end
  |> List.flatten()
  |> Enum.sum()

total_sessions = length(sessions)
avg_groups_per_session = if total_sessions > 0, do: Float.round(group_sessions_created / total_sessions, 1), else: 0

IO.puts("    ✅ Group sessions seeded (#{group_sessions_created} associations created, avg #{avg_groups_per_session} groups per session)")
