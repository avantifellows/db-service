defmodule DbserviceWeb.ErrorHelpers do
  import Ecto.Changeset

  @doc """
  Formats changeset errors for JSON response.
  """
  def errors_for_changeset(changeset) do
    IO.inspect(changeset, label: "changeset")

    traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", inspect(value))
      end)
    end)
  end
end
