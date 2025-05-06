defmodule Dbservice.Topics do
  @moduledoc """
  The Topics context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Topics.Topic
  alias Dbservice.TopicCurriculums.TopicCurriculum
  alias Dbservice.TopicCurriculums

  @doc """
  Returns the list of topic.
  ## Examples
      iex> list_topic()
      [%Topic{}, ...]
  """
  def list_topic do
    Repo.all(Topic)
  end

  @doc """
  Gets a single topic.
  Raises `Ecto.NoResultsError` if the topic does not exist.
  ## Examples
      iex> get_topic!(123)
      %Topic{}
      iex> get_topic!(456)
      ** (Ecto.NoResultsError)
  """
  def get_topic!(id), do: Repo.get!(Topic, id)

  @doc """
  Gets a topic by code.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_topic_by_code(12)
      %School{}

      iex> get_topic_by_code(12)
      ** (Ecto.NoResultsError)

  """
  def get_topic_by_code(code) do
    Repo.get_by(Topic, code: code)
  end

  @doc """
  Creates a topic.
  ## Examples
      iex> create_topic(%{field: value})
      {:ok, %Topic{}}
      iex> create_topic(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_topic(attrs \\ %{}) do
    %Topic{}
    |> Topic.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a topic and associates it with a curriculum if `curriculum_id` is provided.

  ## Examples

      iex> create_topic_with_curriculum(%{
      ...>   "title" => "Topic 1",
      ...>   "curriculum_id" => 1,
      ...>   "priority" => 1,
      ...>   "priority_text" => "High"
      ...> })
      {:ok, %Topic{}}

      iex> create_topic_with_curriculum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_topic_with_curriculum(attrs \\ %{}) do
    curriculum_id = Map.get(attrs, "curriculum_id")

    if curriculum_id do
      with {:ok, %Topic{} = topic} <- create_topic(attrs),
           topic_curriculum_attrs = %{
             "topic_id" => topic.id,
             "curriculum_id" => curriculum_id,
             "priority" => Map.get(attrs, "priority"),
             "priority_text" => Map.get(attrs, "priority_text")
           },
           {:ok, %TopicCurriculum{}} <-
             TopicCurriculums.create_topic_curriculum(topic_curriculum_attrs) do
        {:ok, topic}
      end
    else
      create_topic(attrs)
    end
  end

  @doc """
  Updates a topic and its associated curriculum data if `curriculum_id` is provided.

  ## Examples

      iex> update_topic_with_curriculum(topic, %{
      ...>   "title" => "Updated Title",
      ...>   "curriculum_id" => 1,
      ...>   "priority" => 2,
      ...>   "priority_text" => "Medium"
      ...> })
      {:ok, %Topic{}}

      iex> update_topic_with_curriculum(topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_topic_with_curriculum(topic, attrs \\ %{}) do
    curriculum_id = Map.get(attrs, "curriculum_id")

    if curriculum_id do
      with {:ok, %Topic{} = updated_topic} <- update_topic(topic, attrs) do
        topic_curriculum_attrs = %{
          "topic_id" => updated_topic.id,
          "curriculum_id" => curriculum_id,
          "priority" => Map.get(attrs, "priority"),
          "priority_text" => Map.get(attrs, "priority_text")
        }

        case TopicCurriculums.get_topic_curriculum_by_topic_id_and_curriculum_id(
               updated_topic.id,
               curriculum_id
             ) do
          nil ->
            TopicCurriculums.create_topic_curriculum(topic_curriculum_attrs)

          existing_topic_curriculum ->
            TopicCurriculums.update_topic_curriculum(
              existing_topic_curriculum,
              topic_curriculum_attrs
            )
        end

        {:ok, updated_topic}
      end
    else
      update_topic(topic, attrs)
    end
  end

  @doc """
  Updates a topic.
  ## Examples
      iex> update_topic(topic, %{field: new_value})
      {:ok, %Topic{}}
      iex> update_topic(topic, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_topic(%Topic{} = topic, attrs) do
    topic
    |> Topic.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a topic.
  ## Examples
      iex> delete_topic(topic)
      {:ok, %Topic{}}
      iex> delete_topic(topic)
      {:error, %Ecto.Changeset{}}
  """
  def delete_topic(%Topic{} = topic) do
    Repo.delete(topic)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic changes.
  ## Examples
      iex> change_topic(topic)
      %Ecto.Changeset{data: %Topic{}}
  """
  def change_topic(%Topic{} = topic, attrs \\ %{}) do
    Topic.changeset(topic, attrs)
  end
end
