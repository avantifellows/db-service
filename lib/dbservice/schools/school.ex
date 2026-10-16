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
  # No school grade holds more than a few thousand students; a larger number is
  # a total typed into a per-grade cell, or a stray digit.
  @max_estimated_strength 10_000

  def support_statuses, do: @support_statuses
  def residential_statuses, do: @residential_statuses
  def estimated_strength_fields, do: @estimated_strength_fields

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
    # Nullable on purpose: nil is "not surveyed yet", false is "does not offer
    # these grades". Defaulting to false would lose that distinction.
    field :has_grades_6_to_8, :boolean
    field :has_grades_9_to_10, :boolean
    field :has_grades_11_to_12, :boolean

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
      attrs,
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
        :has_grades_6_to_8,
        :has_grades_9_to_10,
        :has_grades_11_to_12,
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
    |> trim_to_nil(:school_notes)
    |> check_constraint(:school_support_status, name: :school_support_status_check)
    |> check_constraint(:school_residential_status, name: :school_residential_status_check)
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
