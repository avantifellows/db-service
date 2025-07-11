defmodule Dbservice.Repo.Migrations.AddExamIdsToResource do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add :exam_ids, {:array, :bigint}
      add :show_in_gurukul, :boolean, default: false
    end

    # Data migration: Copy exam_ids from tag_ids by matching tag name to exam name
    execute """
    UPDATE resource SET exam_ids = (
      SELECT array_agg(exam.id)
      FROM unnest(tag_ids) AS tag_id
      JOIN tag ON tag.id = tag_id
      JOIN exam ON lower(exam.name) = lower(tag.name)
    )
    WHERE tag_ids IS NOT NULL AND array_length(tag_ids, 1) > 0;
    """

    # Clean up tag_ids after migration
    execute """
    UPDATE resource SET tag_ids = NULL;
    """
  end
end
