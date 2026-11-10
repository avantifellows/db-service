defmodule Dbservice.Schools.School do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Dbservice.Utils.Util

  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Users.User

  @support_statuses ["Supportive", "Non-Supportive", "Neutral"]
  @residential_statuses ["Residential", "Non-Residential"]
  @streams ["Science", "Commerce", "Arts (Humanities)"]
  # What a sheet is likely to carry for each stream, beyond its canonical
  # spelling. Matched case-insensitively, so only the shape has to be listed.
  @stream_aliases %{
    "arts" => "Arts (Humanities)",
    "humanities" => "Arts (Humanities)",
    "arts (humanities)" => "Arts (Humanities)",
    "arts(humanities)" => "Arts (Humanities)",
    "science" => "Science",
    "commerce" => "Commerce"
  }
  # Only 11 and 12 are sized: the other grades are recorded as offered or not,
  # and a per-grade estimate nobody fills reads as "none" rather than "unknown".
  @strength_grades 11..12
  @estimated_strength_fields Enum.map(@strength_grades, &:"estimated_strength_grade_#{&1}")
  # Grades a school can run. Wider than the 11-12 the estimated strength covers,
  # so a school that also runs primary grades can say so.
  @offerable_grades 1..12
  # No school grade holds more than a few thousand students; a larger number is
  # a total typed into a per-grade cell, or a stray digit.
  @max_estimated_strength 10_000

  def support_statuses, do: @support_statuses
  def residential_statuses, do: @residential_statuses
  def streams, do: @streams
  def estimated_strength_fields, do: @estimated_strength_fields
  def offerable_grades, do: @offerable_grades

  schema "school" do
    field :code, :string
    field :name, :string
    field :udise_code, :string
    field :gender_type, :string
    field :af_school_category, :string
    field :region, :string
    field :state_code, :string
    field :state, :string
    field :district_code, :string
    field :district, :string
    field :block_code, :string
    field :block_name, :string
    field :board, :string
    # field :board_medium, :string
    field :program_ids, {:array, :integer}, default: []
    field :school_email, :string
    field :principal_incharge_name, :string
    field :principal_incharge_contact, :string
    field :pmu_coordinator_name, :string
    field :pmu_coordinator_contact, :string
    field :school_support_status, :string
    field :school_residential_status, :string
    # The grades the school runs, e.g. [6, 7, 8, 9, 10]. No default: nil is
    # "not surveyed yet", [] is a surveyed school that runs none of them.
    field :grades_offered, {:array, :integer}
    # The streams the school runs at senior secondary, e.g. ["Science",
    # "Commerce"]. Same reading of nil and [] as grades_offered.
    field :school_stream, {:array, :string}

    for grade <- @strength_grades do
      field :"estimated_strength_grade_#{grade}", :integer
    end

    field :school_notes, :string

    has_many :group, Group, foreign_key: :child_id, where: [type: "school"]

    has_many :enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "school"]

    belongs_to(:user, User)

    timestamps()
  end

  @doc false
  def changeset(school, attrs) do
    school
    |> cast(
      attrs |> normalize_grades_offered() |> normalize_school_stream(),
      [
        :code,
        :name,
        :udise_code,
        :gender_type,
        :af_school_category,
        :region,
        :state_code,
        :state,
        :district_code,
        :district,
        :block_code,
        :block_name,
        :board,
        # :board_medium,
        :user_id,
        :program_ids,
        :school_email,
        :principal_incharge_name,
        :principal_incharge_contact,
        :pmu_coordinator_name,
        :pmu_coordinator_contact,
        :school_support_status,
        :school_residential_status,
        :grades_offered,
        :school_stream,
        :school_notes
      ] ++ @estimated_strength_fields
    )
    |> validate_required([
      :code,
      :name,
      :af_school_category,
      :district_code,
      :district,
      :state_code,
      :state
    ])
    |> validate_contact_details()
    |> validate_statuses()
    |> validate_estimated_strength()
    |> validate_grades_offered()
    |> validate_school_stream()
    |> trim_to_nil(:school_notes)
    |> check_constraint(:school_support_status, name: :school_support_status_check)
    |> check_constraint(:school_residential_status, name: :school_residential_status_check)
    |> check_constraint(:grades_offered, name: :school_grades_offered_check)
    |> check_constraint(:school_stream, name: :school_stream_check)
  end

  # Ops fills one comma-separated cell - "6,7,8,9,10" - and the API sends a JSON
  # array. Ecto would reject the string before any validation could explain why,
  # so the string form is turned into a list here, ahead of the cast. Anything
  # that is not a list of grades is left alone for `cast` to reject.
  defp normalize_grades_offered(attrs), do: split_cell(attrs, :grades_offered, &parse_grade/1)

  # Same deal for the streams - "Science, Commerce" in one cell, a JSON array
  # over the API. Entries are left as written here; `validate_school_stream`
  # matches them against the allowed list.
  defp normalize_school_stream(attrs), do: split_cell(attrs, :school_stream, & &1)

  defp split_cell(attrs, field, parse) when is_map(attrs) do
    case fetch_field_value(attrs, field) do
      {key, value} when is_binary(value) ->
        Map.put(attrs, key, split_values(value, parse))

      _ ->
        attrs
    end
  end

  defp split_cell(attrs, _field, _parse), do: attrs

  defp fetch_field_value(attrs, field) do
    string_key = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> {field, attrs[field]}
      Map.has_key?(attrs, string_key) -> {string_key, attrs[string_key]}
      true -> nil
    end
  end

  defp split_values(value, parse) do
    case String.trim(value) do
      # Left for `cast`, which treats a blank string as an explicit nil, the
      # same as every other column here. A blank cell never reaches this: the
      # import drops it from the row first.
      "" ->
        value

      trimmed ->
        trimmed
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(parse)
    end
  end

  # A grade that is not a number is handed to `cast` as-is, which rejects the
  # whole field - better than silently dropping the one bad entry.
  defp parse_grade(grade) do
    case Integer.parse(grade) do
      {number, ""} -> number
      _ -> grade
    end
  end

  defp validate_grades_offered(changeset) do
    changeset
    |> update_change(:grades_offered, fn
      grades when is_list(grades) -> grades |> Enum.uniq() |> Enum.sort()
      grades -> grades
    end)
    |> validate_change(:grades_offered, fn :grades_offered, grades ->
      case Enum.reject(grades, &(&1 in @offerable_grades)) do
        [] ->
          []

        invalid ->
          [
            grades_offered:
              "must be grades #{Enum.min(@offerable_grades)} to #{Enum.max(@offerable_grades)}, got: #{Enum.join(invalid, ", ")}"
          ]
      end
    end)
  end

  # Streams arrive from the same sheets as the statuses do, so "science" and
  # "Arts" are the same answers as their canonical spellings. Anything that is
  # not one of the three still fails, naming what was wrong.
  defp validate_school_stream(changeset) do
    changeset
    |> update_change(:school_stream, fn
      streams when is_list(streams) ->
        streams
        |> Enum.map(&canonicalize_stream/1)
        |> Enum.uniq()
        # Sorted by the canonical order rather than alphabetically, so two
        # sheets listing the same streams differently read as one answer and an
        # unrecognised entry keeps its place for the error message.
        |> Enum.sort_by(fn stream ->
          Enum.find_index(@streams, &(&1 == stream)) || length(@streams)
        end)

      streams ->
        streams
    end)
    |> validate_change(:school_stream, fn :school_stream, streams ->
      case Enum.reject(streams, &(&1 in @streams)) do
        [] ->
          []

        invalid ->
          [
            school_stream:
              "must be one of #{Enum.join(@streams, ", ")}, got: #{Enum.join(invalid, ", ")}"
          ]
      end
    end)
  end

  defp canonicalize_stream(stream) when is_binary(stream) do
    Map.get(@stream_aliases, stream |> String.trim() |> String.downcase(), String.trim(stream))
  end

  defp canonicalize_stream(stream), do: stream

  defp validate_contact_details(changeset) do
    changeset
    |> trim_to_nil(:principal_incharge_name)
    |> trim_to_nil(:pmu_coordinator_name)
    # One shared rule per kind of contact detail, in `Util`, so a school's numbers are
    # held to the same shape as a student's and an exam record's and stay searchable
    # across all three.
    |> validate_email(:school_email)
    |> validate_phone(:principal_incharge_contact)
    |> validate_phone(:pmu_coordinator_contact)
    # The columns are varchar, which counts codepoints, so cap on codepoints -
    # otherwise a name in a non-Latin script passes here and fails on insert.
    |> validate_length(:principal_incharge_name, max: 100, count: :codepoints)
    |> validate_length(:pmu_coordinator_name, max: 100, count: :codepoints)
  end

  defp validate_statuses(changeset) do
    changeset
    |> canonicalize_status(:school_support_status, @support_statuses)
    |> canonicalize_status(:school_residential_status, @residential_statuses)
    |> validate_inclusion(:school_support_status, @support_statuses)
    |> validate_inclusion(:school_residential_status, @residential_statuses)
  end

  # These two are dropdowns in the UI, but they also arrive from field staff
  # filling a sheet, where "supportive" and "SUPPORTIVE" are the same answer.
  # Match on case and store the canonical spelling; anything else still fails
  # validation rather than being guessed at.
  defp canonicalize_status(changeset, field, allowed) do
    update_change(changeset, field, fn
      value when is_binary(value) ->
        trimmed = String.trim(value)
        folded = String.downcase(trimmed)

        Enum.find(allowed, trimmed, &(String.downcase(&1) == folded))

      value ->
        value
    end)
    |> trim_to_nil(field)
  end

  defp validate_estimated_strength(changeset) do
    Enum.reduce(@estimated_strength_fields, changeset, fn field, acc ->
      acc
      |> validate_number(field,
        greater_than_or_equal_to: 0,
        less_than_or_equal_to: @max_estimated_strength
      )
      |> check_constraint(field, name: :school_estimated_strength_check)
    end)
  end
end
