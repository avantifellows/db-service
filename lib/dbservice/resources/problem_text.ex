defmodule Dbservice.Resources.ProblemText do
  @moduledoc """
  Shared normalization of a problem's question text into a plain-text form used
  for trigram similarity search (duplicate-problem detection, issue #700).

  The same function is used both when persisting `problem_lang.question_plain_text`
  (via the changeset) and when normalizing an incoming search query, so stored
  candidates and queries are scored on identical text.

  Rules:
    * strip HTML tags only — LaTeX/math (`\\(...\\)`, `\\hat{}`, `\\sin`, …) is left
      intact because it is meaningful content and two copies of the same question
      use near-identical LaTeX, which helps the match;
    * insert whitespace at element boundaries so words in adjacent blocks
      (`<div>A</div><div>B</div>`) don't fuse into `AB` and distort trigrams;
    * collapse runs of whitespace and trim.
  """

  @doc """
  Normalizes question HTML to plain text. Returns `""` for `nil`, non-binaries,
  or text that is blank once tags are stripped.
  """
  def to_plain_text(text) when is_binary(text) do
    case Floki.parse_fragment(text) do
      {:ok, tree} -> tree |> Floki.text(sep: " ") |> collapse_whitespace()
      # Malformed markup: fall back to treating the raw string as text.
      _ -> collapse_whitespace(text)
    end
  end

  def to_plain_text(_), do: ""

  defp collapse_whitespace(string) do
    string
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end
end
