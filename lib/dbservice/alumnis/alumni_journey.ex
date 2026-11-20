defmodule Dbservice.Alumnis.AlumniJourney do
  @moduledoc """
  One insert-only row per follow-up with an alumnus: a full snapshot of their
  alumni answers as of `reported_on`, plus which answers changed since the
  previous row. `alumni` keeps the latest state; this table keeps the history
  that updating `alumni` in place would otherwise lose.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @sources ~w(initial call form bulk_upload correction)

  schema "alumni_journey" do
    field :reported_on, :date
    field :reported_year, :integer, read_after_writes: true
    field :source, :string
    field :contact_status, :string
    field :data, :map
    field :changed_fields, {:array, :string}, default: []
    field :actor_email, :string
    field :actor_role, :string
    field :notes, :string

    belongs_to :alumni, Dbservice.Alumnis.Alumni

    timestamps()
  end

  def sources, do: @sources

  @doc false
  def changeset(journey, attrs) do
    journey
    |> cast(attrs, [
      :alumni_id,
      :reported_on,
      :source,
      :contact_status,
      :data,
      :changed_fields,
      :actor_email,
      :actor_role,
      :notes
    ])
    |> validate_required([:alumni_id, :reported_on, :source, :data, :actor_email])
    |> validate_inclusion(:source, @sources)
    |> validate_length(:source, max: 50)
    |> foreign_key_constraint(:alumni_id)
    |> check_constraint(:source, name: :alumni_journey_source_check)
  end
end
