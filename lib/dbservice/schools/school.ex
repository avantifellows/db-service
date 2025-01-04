defmodule Dbservice.Schools.School do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Users.User

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
    |> cast(attrs, [
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
      :user_id
    ])
    |> validate_required([:code, :name])
  end
end
