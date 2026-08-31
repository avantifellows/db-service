defmodule Dbservice.EnrollmentRecords.EnrollmentRecord do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Users.User
  alias Dbservice.Subjects.Subject

  schema "enrollment_record" do
    field :start_date, :date
    field :end_date, :date
    field :is_current, :boolean, default: true
    field :academic_year, :string
    field :group_id, :integer
    field :group_type, :string

    belongs_to(:subject, Subject)

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(enrollment_record, attrs) do
    required_fields = [:user_id, :group_id, :group_type, :start_date]

    group_type = Map.get(attrs, "group_type") || Map.get(enrollment_record, :group_type)

    required_fields =
      if group_type != "auth_group" do
        [:academic_year | required_fields]
      else
        required_fields
      end

    enrollment_record
    |> cast(attrs, [
      :user_id,
      :start_date,
      :end_date,
      :is_current,
      :academic_year,
      :group_id,
      :group_type,
      :subject_id
    ])
    |> validate_required(required_fields)
    |> validate_academic_year_format
    |> validate_dates_of_enrollment
  end

  # Enforces the canonical YYYY-YYYY academic year (e.g. "2026-2027"): both the
  # YYYY-YYYY shape (rejecting short forms like "2026-27" that leaked in via
  # imports) and consecutive years (rejecting "2025-2027"). Skips nil, so
  # auth_group enrollment records (which carry no academic year) are unaffected.
  # Paired with the DB check constraint of the same name as a hard backstop.
  defp validate_academic_year_format(changeset) do
    changeset
    |> validate_format(:academic_year, ~r/\A\d{4}-\d{4}\z/,
      message: "must be in YYYY-YYYY format (e.g. 2026-2027)"
    )
    |> validate_consecutive_academic_year()
    |> check_constraint(:academic_year,
      name: :enrollment_record_academic_year_format,
      message: "must be a consecutive-year range in YYYY-YYYY format (e.g. 2026-2027)"
    )
  end

  # An academic year spans two consecutive calendar years, so the end year must be
  # the start year + 1 (e.g. "2026-2027" is valid, "2025-2027" is not). Shape errors
  # are already reported by validate_format/3 above; this only adds the range check
  # for well-formed, non-nil values.
  defp validate_consecutive_academic_year(changeset) do
    validate_change(changeset, :academic_year, fn :academic_year, value ->
      case parse_academic_year(value) do
        {start_year, end_year} when end_year != start_year + 1 ->
          [academic_year: "must span consecutive years (e.g. 2026-2027)"]

        _ ->
          []
      end
    end)
  end

  defp parse_academic_year(value) when is_binary(value) do
    case Regex.run(~r/\A(\d{4})-(\d{4})\z/, value) do
      [_, start_year, end_year] -> {String.to_integer(start_year), String.to_integer(end_year)}
      _ -> :error
    end
  end

  defp parse_academic_year(_value), do: :error

  defp validate_dates_of_enrollment(changeset) do
    if get_field(changeset, :start_date, :end_date) != nil do
      validate_date_range(changeset, :start_date, :end_date)
    else
      changeset
    end
  end
end
