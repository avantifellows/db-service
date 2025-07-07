defmodule Dbservice.Resources.Resource do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.Teacher
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic
  alias Dbservice.Resources.ResourceCurriculum
  alias Dbservice.Resources.ProblemLanguage

  schema "resource" do
    field(:name, {:array, :map})
    field(:type, :string)
    field(:type_params, :map)
    field(:subtype, :string)
    field(:source, :string)
    field(:code, :string)
    field(:purpose_ids, {:array, :integer})
    field(:tag_ids, {:array, :integer})
    field(:skill_ids, {:array, :integer})
    field(:learning_objective_ids, {:array, :integer})
    field(:cms_status, :string)

    timestamps()

    many_to_many(:chapter, Chapter, join_through: "resource_chapter", on_replace: :delete)
    many_to_many(:topic, Topic, join_through: "resource_topic", on_replace: :delete)
    belongs_to(:teacher, Teacher)
    has_many(:resource_curriculum, ResourceCurriculum)
    has_many(:problem_language, ProblemLanguage, foreign_key: :res_id)
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [
      :name,
      :type,
      :type_params,
      :subtype,
      :source,
      :code,
      :purpose_ids,
      :tag_ids,
      :skill_ids,
      :learning_objective_ids,
      :teacher_id,
      :cms_status
    ])
    |> validate_required([:type, :type_params])
  end
end
