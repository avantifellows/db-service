defmodule Dbservice.Repo.Migrations.CreateCentreExamTracks do
  use Ecto.Migration

  def change do
    create table(:centre_exam_tracks) do
      add :centre_id, references(:centres, on_delete: :nothing), null: false
      add :grade_id, references(:grade, on_delete: :nothing), null: false
      add :exam_track_code, :string, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:centre_exam_tracks, [:centre_id, :grade_id, :exam_track_code],
             name: :centre_exam_tracks_centre_grade_track_unique
           )

    create index(:centre_exam_tracks, [:grade_id])
  end
end
