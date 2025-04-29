defmodule Dbservice.MixProject do
  use Mix.Project

  def project do
    [
      app: :dbservice,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers() ++ [:phoenix_swagger],
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
      extra_applications: [:logger, :runtime_tools, :ex_json_schema]
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
      {:calendar, "~> 1.0.0"},
      {:cors_plug, "~> 3.0.3"},
      {:credo, "~> 1.7.12", only: [:dev], runtime: false},
      {:csv, "~> 3.2.2"},
      {:dialyxir, "~> 1.4.5", only: [:dev], runtime: false},
      {:dotenvy, "~> 1.1.0"},
      {:ecto_sql, "~> 3.12.0"},
      {:esbuild, "~> 0.9.0", runtime: Mix.env() == :dev},
      {:ex_check, "~> 0.16.0", only: [:dev], runtime: false},
      {:ex_json_schema, "~> 0.10.0"},
      {:faker, "~> 0.18.0", only: [:test, :dev]},
      {:gettext, "~> 0.26.0"},
      {:google_api_sheets, "~> 0.29.0"},
      {:goth, "~> 1.4.5"},
      {:hackney, "~> 1.23.0"},
      {:httpoison, "~> 2.2"},
      {:jason, "~> 1.4.4"},
      {:logger_file_backend, "~> 0.0.13"},
      {:oban, "~> 2.18.0"}, # 2.19 needs elixir 1.15
      {:observer_cli, "~> 1.8.3"},
      {:postgrex, "~> 0.20.0"},
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.6.3"},
      {:phoenix_live_dashboard, "~> 0.8.7"},
      {:swoosh, "~> 1.18.4"},
      {:tailwind, "~> 0.3.1", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 1.1.0"},
      {:telemetry_poller, "~> 1.2.0"},
      {:plug_cowboy, "~> 2.7.3"},
      {:phoenix_swagger, "~> 0.8.2"},
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
        "phx.digest"
      ]
    ]
  end
end
