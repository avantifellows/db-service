defmodule Dbservice.Repo.Migrations.CreateBlendedLearningConversationPhotos do
  use Ecto.Migration

  # LMS-owned: af_lms owns product reads and writes of Blended Learning Conversation
  # Photos directly over SQL, so there is no schema/context/controller here. A Mentor may
  # attach up to five images of at most 10 MiB each to a Conversation as evidence of an
  # in-person meeting. Rows are append-only; the image itself lives in S3.
  #
  # Blended Learning migration 5 of 8.

  @table :blended_learning_conversation_photos
  @conversations :blended_learning_conversations

  def change do
    create table(@table) do
      add :conversation_id, references(@conversations, on_delete: :nothing), null: false
      add :s3_key, :text, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :position, :integer, null: false

      timestamps(default: fragment("now()"), null: false, updated_at: false)
    end

    create unique_index(@table, [:conversation_id, :position],
             name: :bl_conversation_photos_conversation_position_unique
           )

    create constraint(@table, :bl_conversation_photos_position_check,
             check: "position BETWEEN 1 AND 5"
           )

    create constraint(@table, :bl_conversation_photos_s3_key_check,
             check: "s3_key ~ '[^[:space:]]'"
           )

    create constraint(@table, :bl_conversation_photos_content_type_check,
             check: "content_type ~ '^image/'"
           )

    create constraint(@table, :bl_conversation_photos_byte_size_check,
             check: "byte_size BETWEEN 1 AND 10485760"
           )

    execute(
      """
      CREATE FUNCTION blended_learning_protect_conversation_photo()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'Blended Learning Conversation Photos are append-only'
          USING ERRCODE = '23514';
      END;
      $$;
      """,
      "DROP FUNCTION blended_learning_protect_conversation_photo()"
    )

    execute(
      """
      CREATE TRIGGER bl_conversation_photos_immutable
      BEFORE UPDATE OR DELETE ON blended_learning_conversation_photos
      FOR EACH ROW EXECUTE FUNCTION blended_learning_protect_conversation_photo()
      """,
      "DROP TRIGGER bl_conversation_photos_immutable ON blended_learning_conversation_photos"
    )

    execute(
      """
      CREATE TRIGGER bl_conversation_photos_conversation_kind
      BEFORE INSERT OR UPDATE ON blended_learning_conversation_photos
      FOR EACH ROW EXECUTE FUNCTION blended_learning_reject_attempt_reference('conversation_id')
      """,
      "DROP TRIGGER bl_conversation_photos_conversation_kind ON blended_learning_conversation_photos"
    )
  end
end
