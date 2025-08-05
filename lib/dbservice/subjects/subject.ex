defmodule Dbservice.Subjects.Subject do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Tags.Tag
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Users.Teacher
  alias Dbservice.Users.Candidate

  schema "subject" do
    field(:name, :string)
    field(:code, :string)

    timestamps()

    has_many(:chapter, Chapter)
    has_many(:teacher, Teacher)
    has_many(:candidate, Candidate)
    belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [
      :name,
      :code,
      :tag_id
    ])
  end
end
