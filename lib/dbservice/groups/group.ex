defmodule Dbservice.Groups.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Programs.Program
  alias Dbservice.Batches.Batch
  alias Dbservice.Sessions.Session
  alias Dbservice.Schools.EnrollmentRecord

  schema "group_type" do
    field :type, Ecto.Enum, values: [:batch, :group, :cohort, :program, :course]
    field :child_id, :integer

    has_many :group, GroupType
    has_many :program, Program
    has_many :batch, Batch

    many_to_many :user, User, join_through: "group_user", on_replace: :delete
    many_to_many :session, Session, join_through: "group_session", on_replace: :delete
    has_many :enrollment_record, EnrollmentRecord

    timestamps()
  end

  @doc false
  def changeset(group_type, attrs) do
    group_type
    |> cast(attrs, [
      :type,
      :child_id
    ])
    |> validate_required([:type])
  end
end
