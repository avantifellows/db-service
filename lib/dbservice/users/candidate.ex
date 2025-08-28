defmodule Dbservice.Users.Candidate do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Subjects.Subject

  schema "candidate" do
    field :degree, :string
    field :college_name, :string
    field :branch_name, :string
    field :latest_cgpa, :decimal
    field :candidate_id, :string

    belongs_to :user, User
    belongs_to :subject, Subject

    timestamps()
  end

  @doc false
  def changeset(candidate, attrs) do
    candidate
    |> cast(attrs, [
      :user_id,
      :degree,
      :college_name,
      :branch_name,
      :latest_cgpa,
      :subject_id,
      :candidate_id
    ])
    |> validate_required([:user_id, :candidate_id])
  end
end
