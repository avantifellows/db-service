defmodule Dbservice.Utils.ChangesetFormatter do
  @moduledoc """
  Utility module for formatting Ecto changeset errors into human-readable messages.
  """

  @doc """
  Formats changeset errors into a readable string message.

  ## Examples

      iex> changeset = %Ecto.Changeset{errors: [date_of_birth: {"is invalid", [type: :date, validation: :cast]}]}
      iex> ChangesetFormatter.format_errors(changeset)
      "date_of_birth: is invalid"

      iex> changeset = %Ecto.Changeset{errors: [name: {"can't be blank", []}, email: {"is invalid", []}]}
      iex> ChangesetFormatter.format_errors(changeset)
      "name: can't be blank; email: is invalid"
  """
  def format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", _to_string(value))
      end)
    end)
    |> Enum.reduce("", fn {k, v}, acc ->
      joined_errors = Enum.join(v, "; ")
      field_name = k |> Atom.to_string() |> String.replace("_", " ")

      if acc == "" do
        "#{field_name}: #{joined_errors}"
      else
        "#{acc}; #{field_name}: #{joined_errors}"
      end
    end)
  end

  def format_errors(changeset), do: changeset

  @doc """
  Formats changeset errors with row number for import error tracking.
  """
  def format_errors_with_row(%Ecto.Changeset{} = changeset, row_number)
      when is_integer(row_number) do
    error_message = format_errors(changeset)
    "Row #{row_number}: #{error_message}"
  end

  def format_errors_with_row(changeset, _row_number) do
    format_errors(changeset)
  end

  @doc """
  Maps changeset errors for JSON responses (maintains the original behavior).
  """
  def map_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", _to_string(value))
      end)
    end)
  end

  def map_errors(changeset), do: changeset

  # Private helper functions
  defp _to_string(val) when is_list(val) do
    Enum.join(val, ",")
  end

  defp _to_string(val), do: to_string(val)
end
