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

  # Run outside a single DDL transaction (and without the migration lock) so the
  # ALTER, the full-table backfill, and the GIN index build do NOT hold one
  # long-lived exclusive lock on problem_lang for the whole deploy window. The
  # index is built CONCURRENTLY (can't run in a transaction), each backfill batch
  # autocommits, and the ADD COLUMN is metadata-only. Mirrors the repo's existing
  # concurrent-index migrations (e.g. 20260723180512, 20260724110000).
  #
  # Because there is no enclosing transaction, every step is written to be
  # re-runnable (IF NOT EXISTS / add_if_not_exists / idempotent backfill) so an
  # interrupted migration can simply be retried.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @index_name "idx_problem_lang_question_trgm"
  @batch_size 2000

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    # ADD COLUMN of a nullable column with no default is metadata-only — no table
    # rewrite, no long lock.
    alter table(:problem_lang) do
      add_if_not_exists(:question_plain_text, :text)
    end

    flush()

    backfill()

    # CONCURRENTLY so the GIN build does not block reads/writes on problem_lang.
    # Plain CREATE INDEX (no IF NOT EXISTS): an interrupted concurrent build leaves
    # an INVALID index, and IF NOT EXISTS would skip it by name on retry — surface
    # it instead so it can be dropped and rebuilt. Check pg_index.indisvalid after
    # deploy.
    execute("""
    CREATE INDEX CONCURRENTLY #{@index_name}
    ON problem_lang USING gin (question_plain_text gin_trgm_ops)
    """)
  end

  def down do
    execute("DROP INDEX CONCURRENTLY IF EXISTS #{@index_name}")

    alter table(:problem_lang) do
      remove_if_exists(:question_plain_text, :text)
    end
  end

  # Normalizes existing rows in id-keyset batches using the shared function (so
  # backfilled rows score identically to ones written later), pulling only
  # meta_data->>'text' to keep memory bounded. Each batch is applied as a SINGLE
  # set-based UPDATE ... FROM (VALUES ...) rather than one statement per row, and
  # (with the DDL transaction disabled) autocommits so no long lock is held.
  defp backfill(last_id \\ 0) do
    rows =
      from(pl in "problem_lang",
        where: pl.id > ^last_id,
        order_by: [asc: pl.id],
        limit: @batch_size,
        select: {pl.id, fragment("? ->> 'text'", pl.meta_data)}
      )
      |> Repo.all()

    case rows do
      [] ->
        :ok

      _ ->
        rows
        |> Enum.map(fn {id, text} -> {id, ProblemText.to_plain_text(text)} end)
        |> update_batch()

        {next_last_id, _} = List.last(rows)
        backfill(next_last_id)
    end
  end

  # One UPDATE for the whole batch, joining problem_lang against a VALUES list of
  # (id, plain_text) pairs. Normalization is done in Elixir (Floki strips HTML but
  # keeps LaTeX), which SQL can't express, so the values are parameterized here.
  defp update_batch(pairs) do
    placeholders =
      pairs
      |> Enum.with_index()
      |> Enum.map_join(", ", fn {_pair, idx} ->
        "($#{idx * 2 + 1}::bigint, $#{idx * 2 + 2}::text)"
      end)

    params = Enum.flat_map(pairs, fn {id, plain} -> [id, plain] end)

    Repo.query!(
      """
      UPDATE problem_lang AS pl
      SET question_plain_text = data.plain
      FROM (VALUES #{placeholders}) AS data(id, plain)
      WHERE pl.id = data.id
      """,
      params
    )
  end
end
