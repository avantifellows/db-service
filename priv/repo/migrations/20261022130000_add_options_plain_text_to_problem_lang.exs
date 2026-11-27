defmodule Dbservice.Repo.Migrations.AddOptionsPlainTextToProblemLang do
  @moduledoc """
  Adds `problem_lang.options_plain_text` — the HTML-stripped, LaTeX-preserved
  plain text of `meta_data["options"]`, joined into one string — so the
  duplicate-problem search can score a problem's answer options alongside its
  question (issue #777).

  The column is kept in sync on every write by `ProblemLanguage`'s changeset;
  this migration adds the column and backfills existing rows with the same
  normalization function. Structure mirrors
  `20260818120000_add_question_plain_text_to_problem_lang`, which added the
  question counterpart.

  No trigram index, unlike the question column. `similar_problems/2` narrows
  candidates with the `%` operator on `question_plain_text` (which is indexed)
  and only then scores their options, so options similarity is computed over a
  handful of rows and is never a search predicate of its own. A second GIN
  index would be paid for on every write of this table and bought nothing.

  Rows written between this migration and the deploy of the changeset change
  land with the column NULL. That is safe: the search reads a NULL or empty
  `options_plain_text` as "no options stored" and falls back to scoring that
  candidate on its question alone, which is the pre-#777 behaviour.
  """
  use Ecto.Migration

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Resources.ProblemText

  # Run outside a single DDL transaction (and without the migration lock) so the
  # ALTER and the full-table backfill do NOT hold one long-lived exclusive lock
  # on problem_lang for the whole deploy window: each backfill batch autocommits
  # and the ADD COLUMN is metadata-only.
  #
  # Because there is no enclosing transaction, every step is written to be
  # re-runnable (add_if_not_exists / idempotent backfill) so an interrupted
  # migration can simply be retried.
  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch_size 2000

  def up do
    # ADD COLUMN of a nullable column with no default is metadata-only — no table
    # rewrite, no long lock.
    alter table(:problem_lang) do
      add_if_not_exists(:options_plain_text, :text)
    end

    flush()

    backfill()
  end

  def down do
    alter table(:problem_lang) do
      remove_if_exists(:options_plain_text, :text)
    end
  end

  # Normalizes existing rows in id-keyset batches using the shared function (so
  # backfilled rows score identically to ones written later), pulling only
  # meta_data->'options' to keep memory bounded. `meta_data` is jsonb, so the
  # options come back already decoded as a list of strings — or as nil where the
  # key is absent or JSON null, which `options_to_plain_text/1` turns into "".
  # Each batch is applied as a SINGLE set-based UPDATE ... FROM (VALUES ...)
  # rather than one statement per row, and autocommits so no long lock is held.
  defp backfill(last_id \\ 0) do
    rows =
      from(pl in "problem_lang",
        where: pl.id > ^last_id,
        order_by: [asc: pl.id],
        limit: @batch_size,
        select: {pl.id, fragment("? -> 'options'", pl.meta_data)}
      )
      |> Repo.all()

    case rows do
      [] ->
        :ok

      _ ->
        rows
        |> Enum.map(fn {id, options} -> {id, ProblemText.options_to_plain_text(options)} end)
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
      SET options_plain_text = data.plain
      FROM (VALUES #{placeholders}) AS data(id, plain)
      WHERE pl.id = data.id
      """,
      params
    )
  end
end
