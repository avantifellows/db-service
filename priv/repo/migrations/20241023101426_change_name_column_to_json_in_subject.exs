defmodule Dbservice.Repo.Migrations.ChangeNameColumnToJsonInSubject do
  use Ecto.Migration

  def up do
    alter table(:subject) do
      add :new_name, :jsonb
    end

    execute """
    UPDATE subject
    SET new_name = jsonb_build_array(
      jsonb_build_object('lang_id', 1, 'subject', name)
    )
    """

    alter table(:subject) do
      remove :name
    end

    rename table(:subject), :new_name, to: :name
  end

  def down do
    alter table(:subject) do
      add :new_name, :string
    end

    execute """
    UPDATE subject
    SET new_name = name->0->>'subject'
    """

    alter table(:subject) do
      remove :name
    end

    rename table(:subject), :new_name, to: :name
  end
end
