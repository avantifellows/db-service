defmodule Dbservice.Repo.Migrations.UpdateTablesAndColumns do
  use Ecto.Migration

  def change do
    alter table(:student) do
      add :school_medium, :string
    end

    alter table(:batch) do
      add :af_medium, :string
    end

    alter table(:program) do
      add :model, :string
      add :is_current, :boolean, default: true
    end

    # Update the school_medium data
    execute """
    WITH latest_school_enrollments AS (
        SELECT
            user_id,
            group_id as school_id,
            ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY updated_at DESC) as rn
        FROM enrollment_record
        WHERE group_type = 'school'
    )
    UPDATE student s
    SET school_medium = sch.board_medium
    FROM latest_school_enrollments lse
    JOIN school sch ON sch.id = lse.school_id
    WHERE s.user_id = lse.user_id
    AND lse.rn = 1;
    """

    # Temporarily commenting out the removal of board_medium column
    # This column will be kept as a backup until we verify the data migration was successful
    # TODO: Create a separate migration to remove this column after verification

    # alter table(:school) do
    #   remove :board_medium
    # end
  end
end
