alias Dbservice.Repo
alias Dbservice.Sessions.Session
alias Dbservice.FormSchemas.FormSchema
alias Dbservice.Users.User

IO.puts("  → Seeding sessions...")

# Get dependencies
_form_schemas = Repo.all(FormSchema)
users = Repo.all(User)

# Get random users for ownership
random_users = Enum.take_random(users, min(5, length(users)))

sessions_data = [
  %{
    name: "CT10-CENTRE OF MASS-MAINS-N",
    platform: "quiz",
    platform_link: "6715f621e1eb083bfa9b56cc",
    portal_link: "https://auth.avantifellows.org?sessionId=EnableStudents_6715f621e1eb083bfa9b56cc",
    start_time: ~U[2024-10-18 05:30:00Z],
    end_time: ~U[2025-06-01 23:55:00Z],
    session_id: "EnableStudents_6715f621e1eb083bfa9b56cc",
    platform_id: "6715f621e1eb083bfa9b56cc",
    auth_type: "sign-in",
    signup_form: false,
    signup_form_id: nil,
    form_schema_id: nil,
    popup_form: false,
    popup_form_id: nil,
    is_active: true,
    type: "quiz",
    meta_data: %{
      "grade" => "11",
      "group" => "EnableStudents",
      "course" => "Photon",
      "status" => "success",
      "stream" => "engineering",
      "enabled" => 1,
      "batch_id" => "",
      "parent_id" => "EN-11-Photon-Eng-24",
      "test_type" => "omr-assessment",
      "cms_test_id" => "https://cms.peerlearning.com/tests/650008963562d9376d000799?test_set_name=A",
      "report_link" => "https://lnk.avantifellows.org/BfgU",
      "test_format" => "chapter_test",
      "date_created" => "2024-10-18",
      "show_answers" => "No",
      "test_purpose" => "weekly_test",
      "shortened_link" => "https://lnk.avantifellows.org/4v8H",
      "optional_limits" => "NA",
      "infinite_session" => false,
      "test_takers_count" => "10000",
      "admin_testing_link" => "https://quiz.avantifellows.org/quiz/6715f621e1eb083bfa9b56cc?apiKey=6qOO8UdF1EGxLgzwIbQN&userId=test_admin"
    },
    purpose: %{"type" => "attendance", "sub-type" => "quiz"},
    repeat_schedule: %{"type" => "weekly", "params" => [1, 2, 3, 4, 5, 6, 7]},
    owner_id: if(length(random_users) > 0, do: Enum.at(random_users, 0).id, else: nil),
    created_by_id: if(length(random_users) > 0, do: Enum.at(random_users, 0).id, else: nil)
  },
  %{
    name: "UK-CT-CB",
    platform: "quiz",
    platform_link: "6708e40b8a087aa530fac5ee",
    portal_link: "https://auth.avantifellows.org?sessionId=UttarakhandStudents_6708e40b8a087aa530fac5ee",
    start_time: ~U[2024-10-13 06:00:00Z],
    end_time: ~U[2024-10-13 23:45:00Z],
    session_id: "UttarakhandStudents_6708e40b8a087aa530fac5ee",
    platform_id: "6708e40b8a087aa530fac5ee",
    auth_type: "sign-in",
    signup_form: false,
    signup_form_id: nil,
    form_schema_id: nil,
    popup_form: false,
    popup_form_id: nil,
    is_active: true,
    type: "quiz",
    meta_data: %{
      "grade" => "12",
      "group" => "UttarakhandStudents",
      "course" => "Photon",
      "status" => "success",
      "stream" => "medical",
      "enabled" => 1,
      "batch_id" => "",
      "parent_id" => "UK-12-Photon-med-24",
      "test_type" => "assessment",
      "cms_test_id" => "https://cms.peerlearning.com/tests/670365ac3562d9019f00e103",
      "report_link" => "https://lnk.avantifellows.org/Hzqu",
      "test_format" => "chapter_test",
      "date_created" => "2024-10-11",
      "show_answers" => "No",
      "test_purpose" => "weekly_test",
      "shortened_link" => "https://lnk.avantifellows.org/YAGM",
      "optional_limits" => "N/A",
      "has_synced_to_bq" => "FALSE",
      "infinite_session" => false,
      "test_takers_count" => "60",
      "admin_testing_link" => "https://quiz.avantifellows.org/quiz/6708e40b8a087aa530fac5ee?apiKey=6qOO8UdF1EGxLgzwIbQN&userId=test_admin"
    },
    purpose: %{"type" => "attendance", "sub-type" => "quiz"},
    repeat_schedule: %{"type" => "weekly", "params" => [1, 2, 3, 4, 5, 6, 7]},
    owner_id: if(length(random_users) > 1, do: Enum.at(random_users, 1).id, else: nil),
    created_by_id: if(length(random_users) > 1, do: Enum.at(random_users, 1).id, else: nil)
  },
  %{
    name: "9M01_Number System_P1",
    platform: "SCERT-plio",
    platform_link: "http://app.plio.in/scertH/play/atdjqrecyu",
    portal_link: "https://auth.avantifellows.org/?sessionId=HaryanaStudents_HaryanaStudents_9_Foundation_24_001_45432_atdjqrecyu",
    start_time: ~U[2024-05-20 00:15:00Z],
    end_time: ~U[2025-05-20 23:45:00Z],
    session_id: "HaryanaStudents_HaryanaStudents_9_Foundation_24_001_45432_atdjqrecyu",
    platform_id: "atdjqrecyu",
    auth_type: "sign-in",
    signup_form: false,
    signup_form_id: nil,
    form_schema_id: nil,
    popup_form: false,
    popup_form_id: nil,
    is_active: true,
    type: "SCERT-plio",
    meta_data: %{
      "group" => "HaryanaStudents",
      "status" => "success",
      "subject" => "Maths",
      "batch_id" => "HaryanaStudents_9_Foundation_24_001",
      "parent_id" => "HR-9-Foundation-24",
      "updated_keys" => ["end_time"],
      "number_of_fields_in_popup_form" => "2"
    },
    purpose: %{"sub-type" => "plio"},
    repeat_schedule: %{"type" => "weekly", "params" => [1, 2, 3, 4, 5, 6, 7]},
    owner_id: if(length(random_users) > 2, do: Enum.at(random_users, 2).id, else: nil),
    created_by_id: if(length(random_users) > 2, do: Enum.at(random_users, 2).id, else: nil)
  }
]

sessions_created =
  for session_attrs <- sessions_data do
    unless Repo.get_by(Session, session_id: session_attrs.session_id) do
      %Session{}
      |> Session.changeset(session_attrs)
      |> Repo.insert!()
      1
    else
      0
    end
  end
  |> Enum.sum()

IO.puts("    ✅ Sessions seeded (#{length(sessions_data)} total, #{sessions_created} new sessions created)")
