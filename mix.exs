defmodule Dbservice.MixProject do
  use Mix.Project

  def project do
    [
      app: :dbservice,
      version: "0.1.0",
      elixir: "~> 1.18.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Dbservice.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.21"},
      {:phoenix_ecto, "~> 4.6.3"},
      {:ecto_sql, "~> 3.12.1"},
      {:postgrex, "~> 0.20"},
      {:phoenix_live_dashboard, "~> 0.8.6"},
      {:swoosh, "~> 1.18.4"},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_poller, "~> 1.2.0"},
      {:gettext, "~> 0.26.2"},
      {:jason, "~> 1.4.4"},
      {:plug_cowboy, "~> 2.7.3"},
      {:phoenix_swagger, "~> 0.8.3"},
      {:ex_json_schema, "~> 0.7.1"},
      {:faker, "~> 0.18.0", only: [:test, :dev]},
      {:ex_check, "~> 0.16.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.4.5", only: [:dev], runtime: false},
      {:credo, "~> 1.7.12", only: [:dev], runtime: false},
      {:dotenvy, "~> 1.1.0"},
      {:cors_plug, "~> 3.0.3"},
      {:logger_file_backend, "~> 0.0.14"},
      {:calendar, "~> 1.0.0"},
      {:observer_cli, "~> 1.8.3"},
      {:oban, "~> 2.19.4"},
      {:csv, "~> 3.2.2"},
      {:httpoison, "~> 2.2.3"},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      {:phoenix_live_view, "~> 1.0.10"},
      {:esbuild, "~> 0.9", runtime: Mix.env() == :dev},
      {:hackney, "~> 1.24.1"},
      {:google_api_sheets, "~> 0.35.0"},
      {:goth, "~> 1.4.5"},
      {:phoenix_html, "~> 4.1"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        "tailwind dbservice --minify",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
