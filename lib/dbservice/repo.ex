defmodule Dbservice.Repo do
  use Ecto.Repo,
    otp_app: :dbservice,
    adapter: Ecto.Adapters.Postgres
end
