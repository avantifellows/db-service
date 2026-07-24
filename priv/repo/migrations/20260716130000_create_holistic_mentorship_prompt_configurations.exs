defmodule Dbservice.Repo.Migrations.CreateHolisticMentorshipPromptConfigurations do
  use Ecto.Migration

  def change do
    create table(:holistic_mentorship_prompt_versions) do
      add :version, :string, null: false
      add :template_text, :text, null: false
      add :template_hash, :string, null: false

      timestamps(default: fragment("now()"), null: false)
    end

    create table(:holistic_mentorship_prompt_configurations) do
      add :prompt_version_id,
          references(:holistic_mentorship_prompt_versions, on_delete: :nothing),
          null: false

      add :model_id, :string, null: false
      add :state, :string, null: false, default: "inactive"

      timestamps(default: fragment("now()"), null: false)
    end

    create unique_index(:holistic_mentorship_prompt_versions, [:version],
             name: :hm_prompt_versions_version_unique
           )

    create unique_index(
             :holistic_mentorship_prompt_configurations,
             [:prompt_version_id, :model_id],
             name: :hm_prompt_configurations_version_model_unique
           )

    create constraint(
             :holistic_mentorship_prompt_configurations,
             :hm_prompt_configurations_state_check,
             check: "state IN ('inactive', 'active')"
           )

    create unique_index(:holistic_mentorship_prompt_configurations, [:state],
             where: "state = 'active'",
             name: :hm_prompt_configurations_single_active
           )

    execute(
      """
      CREATE FUNCTION holistic_mentorship_protect_prompt_content()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF TG_OP = 'DELETE'
          OR (TG_TABLE_NAME = 'holistic_mentorship_prompt_versions'
              AND ((to_jsonb(NEW) ->> 'version') IS DISTINCT FROM (to_jsonb(OLD) ->> 'version')
                   OR (to_jsonb(NEW) ->> 'template_text') IS DISTINCT FROM (to_jsonb(OLD) ->> 'template_text')
                   OR (to_jsonb(NEW) ->> 'template_hash') IS DISTINCT FROM (to_jsonb(OLD) ->> 'template_hash')))
          OR (TG_TABLE_NAME = 'holistic_mentorship_prompt_configurations'
              AND ((to_jsonb(NEW) ->> 'prompt_version_id') IS DISTINCT FROM (to_jsonb(OLD) ->> 'prompt_version_id')
                   OR (to_jsonb(NEW) ->> 'model_id') IS DISTINCT FROM (to_jsonb(OLD) ->> 'model_id')))
        THEN
          RAISE EXCEPTION 'Prompt content is immutable' USING ERRCODE = '23514';
        END IF;

        RETURN NEW;
      END;
      $$;
      """,
      "DROP FUNCTION holistic_mentorship_protect_prompt_content()"
    )

    execute(
      """
      CREATE TRIGGER hm_prompt_versions_immutable
      BEFORE UPDATE OR DELETE ON holistic_mentorship_prompt_versions
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_prompt_content()
      """,
      "DROP TRIGGER hm_prompt_versions_immutable ON holistic_mentorship_prompt_versions"
    )

    execute(
      """
      CREATE TRIGGER hm_prompt_configurations_immutable
      BEFORE UPDATE OR DELETE ON holistic_mentorship_prompt_configurations
      FOR EACH ROW EXECUTE FUNCTION holistic_mentorship_protect_prompt_content()
      """,
      "DROP TRIGGER hm_prompt_configurations_immutable ON holistic_mentorship_prompt_configurations"
    )
  end
end
