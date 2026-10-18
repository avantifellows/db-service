defmodule Dbservice.ResourceTopics do
  @moduledoc """
  The ResourceTopics context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.ResourceTopic

  @doc """
  Returns the list of resource_topic.
  ## Examples
      iex> list_resource_topic()
      [%ResourceTopic{}, ...]
  """
  def list_resource_topic do
    Repo.all(ResourceTopic)
  end

  @doc """
  Gets a single resource_topic.
  Raises `Ecto.NoResultsError` if the resource_topic does not exist.
  ## Examples
      iex> get_resource_topic!(123)
      %ResourceTopic{}
      iex> get_resource_topic!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource_topic!(id), do: Repo.get!(ResourceTopic, id)

  @doc """
  Gets a resource-curriculum based on resource_id and topic_id.
  Raises `Ecto.NoResultsError` if the ResourceTopic does not exist.
  ## Examples
      iex> get_resource_topic_by_resource_id_and_topic_id(1, 2)
      %ResourceTopic{}
      iex> get_resource_topic_by_resource_id_and_topic_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_resource_topic_by_resource_id_and_topic_id(resource_id, topic_id) do
    Repo.get_by(ResourceTopic, resource_id: resource_id, topic_id: topic_id)
  end

  @doc """
  Returns the ids of every topic mapped to a resource, oldest mapping first.
  A problem may be mapped to several topics, including topics from other
  chapters (issue #784).
  ## Examples
      iex> list_topic_ids_by_resource_id(1)
      [4, 9]
  """
  def list_topic_ids_by_resource_id(resource_id) do
    from(rt in ResourceTopic,
      where: rt.resource_id == ^resource_id,
      order_by: [asc: rt.id],
      select: rt.topic_id
    )
    |> Repo.all()
  end

  @doc """
  Batch counterpart of `list_topic_ids_by_resource_id/1`: one query for many
  resources, returning `resource_id => [topic_id]`. Resources with no topic are
  absent from the map. Use this on listing responses to avoid an N+1 lookup.
  ## Examples
      iex> list_topic_ids_by_resource_ids([1, 2])
      %{1 => [4, 9], 2 => [7]}
  """
  def list_topic_ids_by_resource_ids([]), do: %{}

  def list_topic_ids_by_resource_ids(resource_ids) do
    from(rt in ResourceTopic,
      where: rt.resource_id in ^resource_ids,
      order_by: [asc: rt.id],
      select: {rt.resource_id, rt.topic_id}
    )
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @doc """
  Creates a resource_topic.
  ## Examples
      iex> create_resource_topic(%{field: value})
      {:ok, %ResourceTopic{}}
      iex> create_resource_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource_topic(attrs \\ %{}) do
    %ResourceTopic{}
    |> ResourceTopic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource_topic.
  ## Examples
      iex> update_resource_topic(resource_topic, %{field: new_value})
      {:ok, %ResourceTopic{}}
      iex> update_resource_topic(resource_topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource_topic(%ResourceTopic{} = resource_topic, attrs) do
    resource_topic
    |> ResourceTopic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource_topic.
  ## Examples
      iex> delete_resource_topic(resource)
      {:ok, %ResourceTopic{}}
      iex> delete_resource_topic(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource_topic(%ResourceTopic{} = resource_topic) do
    Repo.delete(resource_topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource_topic changes.
  ## Examples
      iex> change_resource_topic(resource_topic)
      %Ecto.Changeset{data: %ResourceTopic{}}
  """
  def change_resource(%ResourceTopic{} = resource_topic, attrs \\ %{}) do
    ResourceTopic.changeset(resource_topic, attrs)
  end
end
