defmodule Dbservice.Repo.Migrations.RemoveLegacyCentreStream do
  use Ecto.Migration

  # Destructive follow-up to the Centre Exam Track rollout. Run only after
  # AF LMS PR #268 is live in production and nothing reads
  # centres.stream_codes anymore.

  def up do
    drop_if_exists(index(:centres, [:stream_codes], name: :centres_stream_codes_index))

    alter table(:centres) do
      remove(:stream_codes)
    end

    execute("""
    DELETE FROM centre_options
    WHERE option_set_id IN (SELECT id FROM centre_option_sets WHERE code = 'stream')
    """)

    execute("DELETE FROM centre_option_sets WHERE code = 'stream'")
  end

  def down do
    # Restores only the column and index. The deleted stream option rows are
    # seed data owned by the AF LMS option seed script and are not recreated
    # here.
    alter table(:centres) do
      add(:stream_codes, {:array, :text}, default: fragment("'{}'::text[]"), null: false)
    end

    create(index(:centres, [:stream_codes], using: :gin))
  end
end
