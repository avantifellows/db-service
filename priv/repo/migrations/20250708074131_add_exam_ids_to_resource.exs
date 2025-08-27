defmodule Dbservice.Repo.Migrations.AddExamIdsToResource do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add :exam_ids, {:array, :bigint}
      add :subtype, :string
      add :code, :string
    end

    # Clean up tag_ids after migration
    execute """
    UPDATE resource SET tag_ids = NULL;
    """
  end
end
