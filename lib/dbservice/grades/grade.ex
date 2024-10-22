defmodule Dbservice.Grades.Grade do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  # alias Dbservice.Tags.Tag
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic

  schema "grade" do
    field(:number, :integer)

    timestamps()

    has_many(:chapter, Chapter)
    has_many(:topic, Topic)
    # belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(grade, attrs) do
    grade
    |> cast(attrs, [
      :number
      # :tag_id
    ])
  end
end
