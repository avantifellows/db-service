defmodule DbserviceWeb.Router do
  use DbserviceWeb, :router
  use PhoenixSwagger

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", DbserviceWeb do
    pipe_through :api

    resources "/group", GroupController, except: [:new, :edit]

    resources "/user", UserController, only: [:index, :create, :update, :show]
    post "/user/:id/update-batches", UserController, :update_batches
    resources "/student", StudentController, except: [:new, :edit]
    post "/student/register", StudentController, :register
    resources "/teacher", TeacherController, except: [:new, :edit]
    resources "/school", SchoolController, except: [:new, :edit]
    resources "/enrollment-record", EnrollmentRecordController, except: [:new, :edit]
    resources "/session", SessionController, only: [:index, :create, :update, :show]
    post "/session/:id/update-batches", SessionController, :update_batches
    resources "/session-occurence", SessionOccurenceController, except: [:new, :edit]
    resources "/user-session", UserSessionController, except: [:new, :edit]

    def swagger_info do
      %{
        info: %{
          version: "1.0",
          title: "DB Service application"
        }
      }
    end
  end

  scope "/docs/swagger" do
    forward "/", PhoenixSwagger.Plug.SwaggerUI,
      otp_app: :dbservice,
      swagger_file: "swagger.json",
      opts: [disable_validator: true]
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
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: DbserviceWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
