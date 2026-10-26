defmodule Dbservice.Repo.Migrations.CreateBlendedLearningFlagViews do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Flag Views
  # directly over SQL, so there is no schema/context/controller here. A Flag View records,
  # per Flag Recipient team member email, when that person last saw the Mentor Flag list so
  # af_lms can show which flags are new since their last visit.
  #
  # Blended Learning migration 7 of 8.

  @table :blended_learning_flag_views

  def change do
    create table(@table) do
      add :viewer_email, :string, size: 255, null: false
      add :last_seen_at, :utc_datetime, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(@table, ["lower(viewer_email)"], name: :bl_flag_views_viewer_email_unique)

    create constraint(@table, :bl_flag_views_viewer_email_check,
             check: "viewer_email ~ '[^[:space:]]'"
           )
  end
end
