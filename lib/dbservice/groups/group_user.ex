defmodule Dbservice.Groups.GroupUser do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "group_user" do
    field :program_date_of_joining, :utc_datetime
    field :program_student_language, :string

    timestamps()
  end

  @doc false
  def changeset(group_user, attrs) do
    group_user
    |> cast(attrs, [
      :program_date_of_joining,
      :program_student_language
    ])
    |> validate_required([:program_date_of_joining, :program_student_language])
  end
end
