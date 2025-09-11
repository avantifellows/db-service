alias Dbservice.Repo
alias Dbservice.Sessions.UserSession
alias Dbservice.Sessions.SessionOccurrence
alias Dbservice.Sessions.Session
alias Dbservice.Users.User

IO.puts("→ Seeding user sessions...")

session_occurrences = Repo.all(SessionOccurrence)
users = Repo.all(User)

user_sessions_created =
  for session_occurrence <- session_occurrences do
    session = Repo.get!(Session, session_occurrence.session_fk)
    # Pick 3-5 random users for each occurrence
    participant_count = min(:rand.uniform(3) + 2, length(users))
    participants = Enum.take_random(users, participant_count)

    for user <- participants do
      timestamp = session_occurrence.start_time
      # Check for existing
      existing = Repo.get_by(UserSession,
        user_id: user.id,
        session_occurrence_id: session_occurrence.id,
        user_activity_type: "sign-in"
      )

      unless existing do
        %UserSession{}
        |> UserSession.changeset(%{
          user_id: user.id,
          session_id: session.id,
          session_occurrence_id: session_occurrence.id,
          timestamp: timestamp,
          user_activity_type: "sign-in",
          data: %{}
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

IO.puts("    ✅ User sessions seeded (#{user_sessions_created} user sign-ins created)")
