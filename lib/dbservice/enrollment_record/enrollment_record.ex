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
    required_fields = [:user_id, :group_id, :group_type, :start_date, :grade_id]

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
    |> validate_dates_of_enrollment
  end

  defp validate_dates_of_enrollment(changeset) do
    if get_field(changeset, :start_date, :end_date) != nil do
      validate_date_range(changeset, :start_date, :end_date)
    else
      changeset
    end
  end
end
