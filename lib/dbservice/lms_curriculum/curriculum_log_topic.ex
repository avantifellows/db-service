defmodule Dbservice.LmsCurriculum.CurriculumLogTopic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "lms_curriculum_log_topics" do
    belongs_to :curriculum_log, Dbservice.LmsCurriculum.CurriculumLog
    belongs_to :topic, Dbservice.Topics.Topic

    timestamps()
  end

  @doc false
  def changeset(log_topic, attrs) do
    log_topic
    |> cast(attrs, [:curriculum_log_id, :topic_id])
    |> validate_required([:curriculum_log_id, :topic_id])
    |> foreign_key_constraint(:curriculum_log_id)
    |> foreign_key_constraint(:topic_id)
    |> unique_constraint([:curriculum_log_id, :topic_id],
      name: :lms_curriculum_log_topics_log_topic_unique
    )
  end
end
