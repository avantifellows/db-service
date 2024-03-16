defmodule DbserviceWeb.Router do
  use DbserviceWeb, :router
  use PhoenixSwagger

  import Dotenvy

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/api", DbserviceWeb do
    pipe_through(:api)

    resources("/auth-group", AuthGroupController, except: [:new, :edit])
    post("/group-type/:id/update-users", GroupTypeController, :update_users)
    post("/group-type/:id/update-sessions", GroupTypeController, :update_sessions)

    resources("/user", UserController, only: [:index, :create, :update, :show])
    post("/user/:id/update-groups", UserController, :update_group_type)
    resources("/student", StudentController, except: [:new, :edit])
    resources("/teacher", TeacherController, except: [:new, :edit])
    resources("/school", SchoolController, except: [:new, :edit])
    resources("/enrollment-record", EnrollmentRecordController, except: [:new, :edit])
    resources("/session", SessionController, only: [:index, :create, :update, :show])
    post("/session/:id/update-groups", SessionController, :update_groups)
    resources("/session-occurrence", SessionOccurenceController, except: [:new, :edit])
    resources("/user-session", UserSessionController, except: [:new, :edit])
    resources("/group-session", GroupSessionController, except: [:new, :edit])
    resources("/program", ProgramController, except: [:new, :edit])
    resources("/batch", BatchController, except: [:new, :edit])
    resources("/batch-program", BatchProgramController, except: [:new, :edit])
    resources("/group-type", GroupTypeController, except: [:new, :edit])
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
    resources("/source", SourceController, except: [:new, :edit])
    resources("/purpose", PurposeController, except: [:new, :edit])
    resources("/resource", ResourceController, except: [:new, :edit])
    resources("/exam", ExamController)
    resources("/student-exam-record", StudentExamRecordController)
    resources("/session-schedule", SessionScheduleController)

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
