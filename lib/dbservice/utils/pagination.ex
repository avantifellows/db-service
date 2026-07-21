defmodule Dbservice.Utils.Pagination do
  @moduledoc """
  Sanitizes `offset`/`limit` query params for list endpoints.

  Every list endpoint gets a default page size when no `limit` is given and a
  hard cap when one is, so a single request can never ask the database for an
  unbounded number of rows (e.g. `?limit=100000`).

  Limits are configurable:

      config :dbservice, Dbservice.Utils.Pagination,
        default_limit: 1000,
        max_limit: 10_000
  """

  @default_limit 1000
  @max_limit 10_000

  @doc """
  Returns a sane limit from request params (or a raw param value).

  Missing or unparseable values fall back to the default limit; values above
  the max limit are clamped down to it; values below 1 become 1.
  """
  def limit(params) when is_map(params), do: params |> Map.get("limit") |> limit()

  def limit(value) do
    value
    |> to_int(default_limit())
    |> min(max_limit())
    |> max(1)
  end

  @doc """
  Returns a sane offset from request params (or a raw param value).

  Missing, unparseable or negative values become 0.
  """
  def offset(params) when is_map(params), do: params |> Map.get("offset") |> offset()

  def offset(value), do: value |> to_int(0) |> max(0)

  def default_limit, do: config(:default_limit, @default_limit)

  def max_limit, do: config(:max_limit, @max_limit)

  defp config(key, default) do
    :dbservice
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp to_int(value, _default) when is_integer(value), do: value

  defp to_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp to_int(_, default), do: default
end
