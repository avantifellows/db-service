defmodule Dbservice.Resources.ResourceTopic do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Resources.Resource
  alias Dbservice.Topics.Topic

  schema "resource_topic" do
    belongs_to :resource, Resource
    belongs_to :topic, Topic

    timestamps()
  end

  @doc false
  def changeset(resource_topic, attrs) do
    resource_topic
    |> cast(attrs, [
      :resource_id,
      :topic_id
    ])
    |> validate_required([
      :resource_id,
      :topic_id
    ])
  end
end
