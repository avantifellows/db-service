defmodule Dbservice.Repo.Migrations.ProtectRegenerationRequestRunBinding do
  use Ecto.Migration

  def up do
    execute(regeneration_request_guard(true))
  end

  def down do
    execute(regeneration_request_guard(false))
  end

  defp regeneration_request_guard(protect_run_binding?) do
    run_binding_guard =
      if protect_run_binding?,
        do: "OR (OLD.etl_run_id IS NOT NULL AND NEW.etl_run_id IS DISTINCT FROM OLD.etl_run_id)",
        else: ""

    """
    CREATE OR REPLACE FUNCTION holistic_mentorship_protect_regeneration_request_identity()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF NEW.request_key IS DISTINCT FROM OLD.request_key
        OR NEW.requested_by_user_id IS DISTINCT FROM OLD.requested_by_user_id
        OR NEW.student_id IS DISTINCT FROM OLD.student_id
        OR NEW.prompt_configuration_id IS DISTINCT FROM OLD.prompt_configuration_id
        OR NEW.force IS DISTINCT FROM OLD.force
        #{run_binding_guard}
      THEN
        RAISE EXCEPTION 'Regeneration Request identity is immutable' USING ERRCODE = '23514';
      END IF;

      RETURN NEW;
    END;
    $$;
    """
  end
end
