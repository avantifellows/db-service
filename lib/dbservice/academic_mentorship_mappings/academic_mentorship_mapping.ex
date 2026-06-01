defmodule Dbservice.AcademicMentorshipMappings.AcademicMentorshipMapping do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "academic_mentorship_mentor_mentee_mapping" do
    field :academic_year, :string
    field :created_by, :string
    field :updated_by, :string
    field :deleted_at, :utc_datetime
    field :mentor_id, :integer
    field :mentee_id, :integer

    timestamps()
  end

  @required_fields [:mentor_id, :mentee_id, :academic_year, :created_by]
  @optional_fields [:updated_by, :deleted_at]

  @doc false
  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:academic_year, ~r/^\d{4}-\d{4}$/)
    |> validate_academic_year_consecutive()
    |> foreign_key_constraint(:mentor_id)
    |> foreign_key_constraint(:mentee_id)
    |> unique_constraint([:mentee_id, :academic_year],
      name: :active_mentee_academic_year_unique,
      message: "mentee already has an active mentor for this academic year"
    )
  end

  @doc false
  def soft_delete_changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:deleted_at, :updated_by])
    |> validate_required([:deleted_at])
  end

  defp validate_academic_year_consecutive(changeset) do
    case get_change(changeset, :academic_year) do
      nil ->
        changeset

      year_str ->
        case String.split(year_str, "-") do
          [start_str, end_str] ->
            with {start_year, ""} <- Integer.parse(start_str),
                 {end_year, ""} <- Integer.parse(end_str) do
              if end_year == start_year + 1 do
                changeset
              else
                add_error(changeset, :academic_year, "end year must be start year + 1")
              end
            else
              _ -> add_error(changeset, :academic_year, "invalid year format")
            end

          _ ->
            changeset
        end
    end
  end
end
