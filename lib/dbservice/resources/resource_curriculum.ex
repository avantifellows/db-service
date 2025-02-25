defmodule Dbservice.Resources.ResourceCurriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Resource
  alias Dbservice.Curriculums.Curriculum
  alias Dbservice.Grades.Grade
  alias Dbservice.Subjects.Subject

  schema "resource_curriculum" do
    field :difficulty_level, :string

    timestamps()

    belongs_to :resource, Resource
    belongs_to :curriculum, Curriculum
    belongs_to :grade, Grade
    belongs_to :subject, Subject
  end

  @doc false
  def changeset(resource_curriculum, attrs) do
    resource_curriculum
    |> cast(attrs, [
      :resource_id,
      :curriculum_id,
      :grade_id,
      :subject_id,
      :difficulty_level
    ])
    |> validate_required([
      :resource_id,
      :curriculum_id,
      :grade_id
    ])
  end
end
