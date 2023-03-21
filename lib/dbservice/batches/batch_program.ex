defmodule Dbservice.Batches.BatchProgram do
  @moduledoc false

  use Ecto.Schema
  alias Dbservice.Batches.Batch
  alias Dbservice.Programs.Program
  import Ecto.Changeset

  schema "batch_program" do
    belongs_to :batch, Batch
    belongs_to :program, Program

    timestamps()
  end

  @doc false
  def changeset(batch_program, attrs) do
    batch_program
    |> cast(attrs, [
      :batch_id,
      :program_id
    ])
    |> validate_required([:batch_id, :program_id])
  end
end
