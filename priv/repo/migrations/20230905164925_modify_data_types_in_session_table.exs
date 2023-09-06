defmodule Dbservice.Repo.Migrations.ModifyDataTypesInSessionTable do
  use Ecto.Migration

  def up do
    execute("""
      ALTER TABLE session
      ALTER COLUMN activate_signup TYPE BOOLEAN USING (activate_signup::boolean),
      ALTER COLUMN id_generation TYPE BOOLEAN USING (id_generation::boolean),
      ALTER COLUMN redirection TYPE BOOLEAN USING (redirection::boolean),
      ALTER COLUMN pop_up_form TYPE BOOLEAN USING (pop_up_form::boolean),
      ALTER COLUMN number_of_fields_in_pop_form TYPE INTEGER USING (number_of_fields_in_pop_form::integer);
    """)
  end

  def down do
    execute("""
      ALTER TABLE session
      ALTER COLUMN activate_signup TYPE VARCHAR,
      ALTER COLUMN id_generation TYPE VARCHAR,
      ALTER COLUMN redirection TYPE VARCHAR,
      ALTER COLUMN pop_up_form TYPE VARCHAR,
      ALTER COLUMN number_of_fields_in_pop_form TYPE INTEGER;
    """)
  end
end
