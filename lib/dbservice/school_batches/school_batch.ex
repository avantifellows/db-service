defmodule Dbservice.SchoolBatches.SchoolBatch do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Batches.Batch
  alias Dbservice.Schools.School
  import Ecto.Changeset

  schema "school_batch" do
    belongs_to :school, School
    belongs_to :batch, Batch

    timestamps()
  end

  @doc false
  def changeset(school_batch, attrs) do
    school_batch
    |> cast(attrs, [
      :school_id,
      :batch_id
    ])
    |> validate_required([:school_id, :batch_id])
  end
end
