defmodule Dbservice.TopicCurriculums.TopicCurriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Topics.Topic
  alias Dbservice.Curriculums.Curriculum

  schema "topic_curriculum" do
    belongs_to :topic, Topic
    belongs_to :curriculum, Curriculum
    field :priority, :integer
    field :priority_text, :string

    timestamps()
  end

  def changeset(topic_curriculum, attrs) do
    topic_curriculum
    |> cast(attrs, [:topic_id, :curriculum_id, :priority, :priority_text])
    |> validate_required([:topic_id, :curriculum_id])
  end
end
