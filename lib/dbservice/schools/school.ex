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
  @grades 6..12
  @estimated_strength_fields Enum.map(@grades, &:"estimated_strength_grade_#{&1}")
  # Grades a school can run. Wider than the 6-12 the estimated strength covers,
  # so a school that also runs primary grades can say so.
  @offerable_grades 1..12
  # No school grade holds more than a few thousand students; a larger number is
  # a total typed into a per-grade cell, or a stray digit.
  @max_estimated_strength 10_000

  def support_statuses, do: @support_statuses
  def residential_statuses, do: @residential_statuses
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

    for grade <- @grades do
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
      normalize_grades_offered(attrs),
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
    |> trim_to_nil(:school_notes)
    |> check_constraint(:school_support_status, name: :school_support_status_check)
    |> check_constraint(:school_residential_status, name: :school_residential_status_check)
    |> check_constraint(:grades_offered, name: :school_grades_offered_check)
  end

  # Ops fills one comma-separated cell - "6,7,8,9,10" - and the API sends a JSON
  # array. Ecto would reject the string before any validation could explain why,
  # so the string form is turned into a list here, ahead of the cast. Anything
  # that is not a list of grades is left alone for `cast` to reject.
  defp normalize_grades_offered(attrs) when is_map(attrs) do
    case fetch_grades_offered(attrs) do
      {key, value} when is_binary(value) ->
        Map.put(attrs, key, split_grades(value))

      _ ->
        attrs
    end
  end

  defp normalize_grades_offered(attrs), do: attrs

  defp fetch_grades_offered(attrs) do
    cond do
      Map.has_key?(attrs, :grades_offered) -> {:grades_offered, attrs[:grades_offered]}
      Map.has_key?(attrs, "grades_offered") -> {"grades_offered", attrs["grades_offered"]}
      true -> nil
    end
  end

  defp split_grades(value) do
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
        |> Enum.map(&parse_grade/1)
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

  defp validate_contact_details(changeset) do
    changeset
    |> trim_to_nil(:school_email)
    |> trim_to_nil(:principal_incharge_name)
    |> trim_to_nil(:principal_incharge_contact)
    |> trim_to_nil(:pmu_coordinator_name)
    |> trim_to_nil(:pmu_coordinator_contact)
    # Deliberately loose - the only thing worth rejecting is a value that could
    # not reach a mailbox.
    |> validate_format(:school_email, ~r/\A[^\s@]+@[^\s@]+\.[^\s@]+\z/,
      message: "must be a valid email address"
    )
    # Digits only, as on `user.phone` - a value carrying "+91" or spaces has not
    # been normalized, and storing both forms makes the column unsearchable.
    |> validate_contact_number(:principal_incharge_contact)
    |> validate_contact_number(:pmu_coordinator_contact)
    # The columns are varchar, which counts codepoints, so cap on codepoints -
    # otherwise a name in a non-Latin script passes here and fails on insert.
    |> validate_length(:school_email, max: 255, count: :codepoints)
    |> validate_length(:principal_incharge_name, max: 100, count: :codepoints)
    |> validate_length(:pmu_coordinator_name, max: 100, count: :codepoints)
  end

  defp validate_contact_number(changeset, field) do
    changeset
    |> validate_format(field, ~r/\A\d+\z/, message: "must contain only digits")
    |> validate_length(field, max: 15, count: :codepoints)
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
