defmodule Dbservice.Repo.Migrations.AddInitiatedByToImports do
  use Ecto.Migration

  @moduledoc """
  Records who started each import.

  Until now the imports UI was unauthenticated and the `imports` table had no
  notion of a user, so there was no way to trace bad data back to the person
  who loaded it. Rows created before this migration stay NULL — the
  information was never captured and cannot be backfilled.
  """

  def change do
    alter table(:imports) do
      add(:initiated_by_email, :string)
      add(:initiated_by_name, :string)
    end

    create(index(:imports, [:initiated_by_email]))
  end
end
