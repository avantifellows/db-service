defmodule Dbservice.Grades.Grade do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Tags.Tag
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic
  alias Dbservice.Groups.Group
  alias Dbservice.EnrollmentRecords.EnrollmentRecord

  schema "grade" do
    field(:number, :integer)

    timestamps()

    has_many(:chapter, Chapter)
    has_many(:student, Student)
    has_many(:topic, Topic)
    belongs_to(:tag, Tag)
    has_many(:group, Group, foreign_key: :child_id, where: [type: "grade"])

    has_many(:enrollment_record, EnrollmentRecord,
      foreign_key: :group_id,
      where: [group_type: "group"]
    )
  end

  @doc false
  def changeset(grade, attrs) do
    grade
    |> cast(attrs, [
      :number,
      :tag_id
    ])
  end
end
