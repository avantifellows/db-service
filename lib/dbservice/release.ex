defmodule Dbservice.Release do
  @moduledoc """
  Release tasks invoked from the OTP release binary (`bin/dbservice eval ...`).

  Used by the deploy pipeline to run migrations against the database
  without booting the full app (no web server, no Oban, no Goth).
  """

  @app :dbservice

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp load_app do
    Application.load(@app)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end
end
