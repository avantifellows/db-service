defmodule DbserviceWeb.Router do
  use DbserviceWeb, :router
  use PhoenixSwagger

  import Dotenvy
  import Phoenix.LiveView.Router

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {DbserviceWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", DbserviceWeb do
    pipe_through :browser

    live "/imports", ImportLive.Index
    live "/imports/new", ImportLive.New
    live "/imports/:id", ImportLive.Show
  end

  scope "/api", DbserviceWeb do
    pipe_through(:api)

    resources("/auth-group", AuthGroupController, except: [:new, :edit])
    post("/group/:id/update-users", GroupController, :update_users)
    post("/group/:id/update-sessions", GroupController, :update_sessions)

    resources("/user", UserController, only: [:index, :create, :update, :show])
    post("/user/:id/update-groups", UserController, :update_group)
    get("/student/get-schema", StudentController, :get_schema)
    resources("/student", StudentController, except: [:new, :edit])
    post("/student/generate-id", StudentController, :create_student_id)
    post("/student/verify-student", StudentController, :verify_student)
    resources("/teacher", TeacherController, except: [:new, :edit])
    resources("/user-profile", UserProfileController, except: [:new, :edit])
    resources("/student-profile", StudentProfileController, except: [:new, :edit])
    resources("/teacher-profile", TeacherProfileController, except: [:new, :edit])
    resources("/school", SchoolController, except: [:new, :edit])
    resources("/language", LanguageController, except: [:new, :edit])
    resources("/skill", SkillController, except: [:new, :edit])
    resources("/enrollment-record", EnrollmentRecordController, except: [:new, :edit])
    resources("/session", SessionController, only: [:index, :create, :update, :show])
    post("/session/:id/update-groups", SessionController, :update_groups)
    resources("/session-occurrence", SessionOccurrenceController, except: [:new, :edit])
    resources("/user-session", UserSessionController, except: [:new, :edit])
    get("/group-session/session-auth-group", GroupSessionController, :get_auth_group_from_session)
    resources("/group-session", GroupSessionController, except: [:new, :edit])
    resources("/product", ProductController)
    resources("/program", ProgramController, except: [:new, :edit])
    resources("/batch", BatchController, except: [:new, :edit])
    resources("/group", GroupController, except: [:new, :edit])
    resources("/form-schema", FormSchemaController)
    resources("/group-user", GroupUserController)
    resources("/tag", TagController, except: [:new, :edit])
    resources("/curriculum", CurriculumController, except: [:new, :edit])
    resources("/grade", GradeController, except: [:new, :edit])
    resources("/subject", SubjectController, except: [:new, :edit])
    resources("/chapter", ChapterController, except: [:new, :edit])
    resources("/topic", TopicController, except: [:new, :edit])
    resources("/concept", ConceptController, except: [:new, :edit])
    resources("/learning-objective", LearningObjectiveController, except: [:new, :edit])
    resources("/purpose", PurposeController, except: [:new, :edit])
    resources("/resource", ResourceController, except: [:new, :edit])
    resources("/exam", ExamController)
    resources("/student-exam-record", StudentExamRecordController)
    resources("/session-schedule", SessionScheduleController)
    get("/user/:user_id/sessions", UserController, :get_user_sessions)
    patch("/dropout/:student_id", StudentController, :dropout)
    resources("/status", StatusController, except: [:new, :edit])
    patch("/enrolled", StudentController, :enrolled)
    resources("/school-batch", SchoolBatchController, except: [:new, :edit])
    post("/school-with-user", SchoolController, :create_school_with_user)
    patch("/update-group-user-by-type", GroupUserController, :update_by_type)
    patch("/update-user-enrollment-records", StudentController, :update_user_enrollment_records)
    post("/student/batch-process", StudentController, :batch_process)
    post("/group-user/batch-process", GroupUserController, :batch_process)
    resources("/college", CollegeController, except: [:new, :edit])
    get("/resources/curriculum", ResourceController, :curriculum_resources)
    get("/resource/subtypes/:type", ResourceController, :get_subtypes)

    # Some students were incorrectly marked as "dropouts" in our system. This endpoint was introduced to reverse this mistake by removing the dropout status from both the enrollment records and the student table
    patch("/student/remove-dropout-status/:student_id", StudentController, :remove_dropout_status)
    delete("/cleanup-student/:student_id", UserSessionController, :cleanup_student)
    delete("/remove-batch/:student_id/:batch_id", UserSessionController, :remove_batch_mapping)
    post("/student/:student_id/status", StudentController, :update_student_status)
    resources("/chapter-curriculum", ChapterCurriculumController, except: [:new, :edit])
    resources("/topic-curriculum", TopicCurriculumController, except: [:new, :edit])
    resources("/resource-curriculum", ResourceCurriculumController, except: [:new, :edit])
    resources("/resource-chapter", ResourceChapterController, except: [:new, :edit])
    resources("/resource-topic", ResourceTopicController, except: [:new, :edit])
    resources("/resource-concept", ResourceConceptController, except: [:new, :edit])
    resources("/problem-language", ProblemLanguageController, except: [:new, :edit])
    get("/resource/test/:id/problems", ResourceController, :test_problems)
    get("/problems", ResourceController, :fetch_problems)
    resources("/test-rule", TestRuleController, except: [:new, :edit])

    get(
      "/resource/problem/:problem_id/:lang_code/:curriculum_id",
      ResourceController,
      :get_problem
    )

    def swagger_info do
      source(["config/.env", "config/.env"])

      host =
        if Application.get_env(:dbservice, :environment) == :dev do
          "localhost:4000"
        else
          env!("PHX_HOST", :string!)
        end

      %{
        info: %{
          version: "1.0",
          title: "DB Service application"
        },
        host: host
      }
    end
  end

  scope "/docs/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :dbservice,
      swagger_file: "swagger.json",
      opts: [disable_validator: true]
    )
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through([:fetch_session, :protect_from_forgery])

      live_dashboard("/dashboard", metrics: DbserviceWeb.Telemetry)
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through([:fetch_session, :protect_from_forgery])

      forward("/mailbox", Plug.Swoosh.MailboxPreview)
    end
  end
end
