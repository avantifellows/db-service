defmodule Dbservice.Repo.Migrations.AddQuestionPlainTextToProblemLang do
  @moduledoc """
  Adds `problem_lang.question_plain_text` — the HTML-stripped, LaTeX-preserved
  plain text of `meta_data["text"]` — plus a pg_trgm GIN index, to power the
  fuzzy duplicate-problem search (issue #700).

  The column is kept in sync on every write by `ProblemLanguage`'s changeset;
  this migration enables the extension, adds the column, backfills existing rows
  with the same normalization function, and creates the trigram index.
  """
  use Ecto.Migration

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Resources.ProblemText

  @index_name "idx_problem_lang_question_trgm"

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    alter table(:problem_lang) do
      add(:question_plain_text, :text)
    end

    flush()

    backfill()

    execute("""
    CREATE INDEX #{@index_name}
    ON problem_lang USING gin (question_plain_text gin_trgm_ops)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS #{@index_name}")

    alter table(:problem_lang) do
      remove(:question_plain_text)
    end
  end

  # Normalizes existing rows in id-keyset batches using the shared function, so
  # backfilled rows score identically to ones written after this migration. Only
  # meta_data->>'text' is pulled per row (not the whole meta_data blob) to keep
  # memory bounded on a large problem bank.
  defp backfill(last_id \\ 0) do
    batch =
      from(pl in "problem_lang",
        where: pl.id > ^last_id,
        order_by: [asc: pl.id],
        limit: 2000,
        select: {pl.id, fragment("? ->> 'text'", pl.meta_data)}
      )
      |> Repo.all()

    case batch do
      [] ->
        :ok

      rows ->
        Enum.each(rows, fn {id, text} ->
          plain = ProblemText.to_plain_text(text)

          from(pl in "problem_lang", where: pl.id == ^id)
          |> Repo.update_all(set: [question_plain_text: plain])
        end)

        {next_last, _} = List.last(rows)
        backfill(next_last)
    end
  end
end
