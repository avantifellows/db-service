alias Dbservice.Repo
alias Dbservice.Sessions.SessionOccurrence
alias Dbservice.Sessions.Session

IO.puts("  → Seeding session occurrences...")

# Get all sessions
sessions = Repo.all(Session)

session_occurrences_created =
  for session <- sessions do
    # Create 2-4 occurrences for each session (representing past and future occurrences)
    occurrence_count = :rand.uniform(3) + 1 # 2-4 occurrences

    for i <- 1..occurrence_count do
      # Generate occurrence times based on session schedule
      days_offset = case i do
        1 -> -7  # 1 week ago
        2 -> 0   # today/scheduled time
        3 -> 7   # 1 week from now
        4 -> 14  # 2 weeks from now
      end

      occurrence_start = session.start_time |> DateTime.add(days_offset, :day)
      occurrence_end = session.end_time |> DateTime.add(days_offset, :day)

      # Check if this occurrence already exists for this session and time
      unless Repo.get_by(SessionOccurrence, session_id: session.session_id, start_time: occurrence_start) do
        %SessionOccurrence{}
        |> SessionOccurrence.changeset(%{
          session_id: session.session_id,
          session_fk: session.id,
          start_time: occurrence_start,
          end_time: occurrence_end
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
avg_occurrences_per_session = if total_sessions > 0, do: Float.round(session_occurrences_created / total_sessions, 1), else: 0

IO.puts("    ✅ Session occurrences seeded (#{session_occurrences_created} occurrences created, avg #{avg_occurrences_per_session} per session)")
