defmodule Dbservice.Utils.AcademicYear do
  @moduledoc """
  The canonical academic year: `YYYY-YYYY` spanning two consecutive calendar
  years, e.g. "2026-2027". Short forms like "2026-27" and gaps like "2025-2027"
  are not academic years.

  Shared by the enrollment record changeset and the Blended mentor import so
  the rule can't drift. Tables that store academic years back it with their
  own SQL check constraints.
  """

  @doc """
  Splits a `YYYY-YYYY` value into its two years, without checking they are
  consecutive. Returns `:error` for anything else, including non-strings.
  """
  def parse(value) when is_binary(value) do
    case Regex.run(~r/\A(\d{4})-(\d{4})\z/, value) do
      [_, start_year, end_year] ->
        {:ok, {String.to_integer(start_year), String.to_integer(end_year)}}

      _ ->
        :error
    end
  end

  def parse(_value), do: :error

  @doc "True when `value` is `YYYY-YYYY` with the second year one after the first."
  def valid?(value) do
    case parse(value) do
      {:ok, {start_year, end_year}} -> end_year == start_year + 1
      :error -> false
    end
  end
end
