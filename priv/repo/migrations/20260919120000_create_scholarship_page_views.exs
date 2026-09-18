defmodule Dbservice.Repo.Migrations.CreateScholarshipPageViews do
  use Ecto.Migration

  # Visitor counter for the public scholarship site (af-scholarship `(site)`
  # routes). One row per public path holding a running view count, so the
  # programme team can read both the headline total and the per-page breakdown
  # without a row-per-hit table to prune.
  #
  # Written by the scholarship app at runtime (read/write via `pg`) as an
  # upsert on `path`; authored here per team convention. `path` is constrained
  # app-side to the site's known routes, so the table cannot grow a row per
  # junk URL a bot invents.
  def change do
    create table(:scholarship_page_views) do
      add :path, :string, null: false
      add :views, :bigint, null: false, default: 0

      timestamps()
    end

    create unique_index(:scholarship_page_views, [:path])
  end
end
