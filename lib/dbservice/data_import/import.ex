defmodule Dbservice.DataImport.Import do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "imports" do
    field :filename, :string
    field :status, :string
    field :type, :string
    field :total_rows, :integer
    field :processed_rows, :integer
    field :error_count, :integer, default: 0
    field :error_details, {:array, :map}, default: []
    field :start_row, :integer
    field :completed_at, :utc_datetime

    # Who started this import, captured from the Google SSO session. NULL for
    # rows created before the imports UI required sign-in.
    field :initiated_by_email, :string
    field :initiated_by_name, :string

    timestamps()
  end

  def changeset(import, attrs) do
    import
    |> cast(attrs, [
      :filename,
      :status,
      :type,
      :total_rows,
      :processed_rows,
      :error_count,
      :error_details,
      :start_row,
      :completed_at,
      :initiated_by_email,
      :initiated_by_name
    ])
    |> validate_required([:filename, :status, :type])
  end
end
