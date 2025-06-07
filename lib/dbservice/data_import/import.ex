defmodule Dbservice.DataImport.Import do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "imports" do
    field :filename, :string
    field :status, :string
    field :type, :string
    field :sheet_url, :string
    field :total_rows, :integer
    field :processed_rows, :integer
    field :error_count, :integer, default: 0
    field :error_details, {:array, :map}, default: []
    field :start_row, :integer
    field :completed_at, :utc_datetime

    timestamps()
  end

  def changeset(import, attrs) do
    import
    |> cast(attrs, [
      :filename,
      :status,
      :type,
      :sheet_url,
      :total_rows,
      :processed_rows,
      :error_count,
      :error_details,
      :start_row,
      :completed_at
    ])
    |> validate_required([:type])
    |> validate_inclusion(:type, ["student"])
  end
end
