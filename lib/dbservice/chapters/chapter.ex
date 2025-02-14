defmodule Dbservice.Chapters.Chapter do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Grades.Grade
  alias Dbservice.Subjects.Subject
  alias Dbservice.Topics.Topic

  schema "chapter" do
    field :name, {:array, :map}
    field(:code, :string)

    timestamps()

    has_many(:topic, Topic)
    belongs_to(:grade, Grade)
    belongs_to(:subject, Subject)
  end

  @doc false
  def changeset(chapter, attrs) do
    chapter
    |> cast(attrs, [
      :name,
      :code,
      :grade_id,
      :subject_id
    ])
  end
end
