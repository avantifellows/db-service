defmodule DbserviceWeb.ChangesetJSON do
  alias DbserviceWeb.ErrorHelpers

  @doc """
  Traverses and translates changeset errors.

  See `Ecto.Changeset.traverse_errors/2` and
  `DbserviceWeb.ErrorHelpers.translate_error/1` for more details.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)
  end

  def error(%{changeset: changeset}) do
    # Transform changeset errors into a map of errors
    # See Ecto.Changeset.traverse_errors/2 and
    # Phoenix.HTML.Form.input_validations/2 for more examples
    # of error message formatting.
    %{
      errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    }
  end
end
