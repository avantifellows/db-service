defmodule Dbservice.Repo.Migrations.AddKeyToBlendedLearningCommonActionItems do
  use Ecto.Migration

  # LMS-owned, like the rest of Blended Learning: af_lms reads and writes this table
  # directly over SQL, so there is no schema/context/controller here.
  #
  # A hidden, fixed key on a Common Action Item that af_lms needs to find by itself.
  # Admins never see or edit it on the Manage page.
  #
  # Why: when a JEE form is recorded as filled, af_lms ticks the Student's open "JEE Form
  # Filling (Reminder)" Action Item. It used to find that Common Action Item by its text,
  # so renaming the item on the Manage page silently stopped the JEE form ticking it.
  # af_lms now finds it by key = 'jee_form_reminder', so the text can change freely.
  #
  # - key: lowercase letters, digits and underscores, starting with a letter; NULL for
  #   ordinary admin-pushed items.
  # - At most one active (not removed) item per key. A removed item keeps its key as
  #   history but no longer holds it, so the reminder can be re-created under the same key.
  #   af_lms looks a key up with `removed_at IS NULL`.
  # - The existing reminder gets its key here, matched by text with case and spacing
  #   ignored (the lowest id if several match). A database without one (fresh, CI) is left
  #   as it is.
  #
  # Rolling back drops the index, the check and the column (and with it every key).

  @common :blended_learning_common_action_items

  def change do
    alter table(@common) do
      add :key, :string, size: 64
    end

    create constraint(@common, :bl_common_action_items_key_check,
             check: "key IS NULL OR key ~ '^[a-z][a-z0-9_]*$'"
           )

    create unique_index(@common, [:key],
             name: :bl_common_action_items_key_unique,
             where: "key IS NOT NULL AND removed_at IS NULL"
           )

    # The column goes on rollback, so undoing the key needs nothing of its own.
    execute(&key_jee_form_reminder/0, fn -> :ok end)
  end

  defp key_jee_form_reminder, do: repo().query!(key_jee_form_reminder_sql())

  @doc false
  def key_jee_form_reminder_sql do
    ~S"""
    UPDATE blended_learning_common_action_items
    SET key = 'jee_form_reminder'
    WHERE id = (
      SELECT min(id)
      FROM blended_learning_common_action_items
      WHERE lower(btrim(regexp_replace(text, '\s+', ' ', 'g'))) = 'jee form filling (reminder)'
        AND removed_at IS NULL
    )
    AND NOT EXISTS (
      SELECT 1
      FROM blended_learning_common_action_items
      WHERE key = 'jee_form_reminder' AND removed_at IS NULL
    )
    """
  end
end
