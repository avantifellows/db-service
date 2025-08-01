defmodule Dbservice.TopicCurriculums do
  @moduledoc """
  The TopicCurriculums context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.TopicCurriculums.TopicCurriculum

  @doc """
  Returns the list of topic_curriculum.
  ## Examples
      iex> list_topic_curriculum()
      [%TopicCurriculum{}, ...]
  """
  def list_topic_curriculum do
    Repo.all(TopicCurriculum)
  end

  @doc """
  Gets a single topic_curriculum.
  Raises `Ecto.NoResultsError` if the topic_curriculum does not exist.
  ## Examples
      iex> get_topic_curriculum!(123)
      %TopicCurriculum{}
      iex> get_topic_curriculum!(456)
      ** (Ecto.NoResultsError)
  """
  def get_topic_curriculum!(id), do: Repo.get!(TopicCurriculum, id)

  @doc """
  Gets a topic-curriculum based on topic_id and curriculum_id.
  Raises `Ecto.NoResultsError` if the TopicCurriculum does not exist.
  ## Examples
      iex> get_topic_curriculum_by_topic_id_and_curriculum_id(1, 2)
      %TopicCurriculum{}
      iex> get_topic_curriculum_by_topic_id_and_curriculum_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_topic_curriculum_by_topic_id_and_curriculum_id(topic_id, curriculum_id) do
    Repo.get_by(TopicCurriculum, topic_id: topic_id, curriculum_id: curriculum_id)
  end

  @doc """
  Creates a topic_curriculum.
  ## Examples
      iex> create_topic_curriculum(%{field: value})
      {:ok, %TopicCurriculum{}}
      iex> create_topic_curriculum(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_topic_curriculum(attrs \\ %{}) do
    %TopicCurriculum{}
    |> TopicCurriculum.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a topic_curriculum.
  ## Examples
      iex> update_topic_curriculum(topic_curriculum, %{field: new_value})
      {:ok, %TopicCurriculum{}}
      iex> update_topic_curriculum(topic_curriculum, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_topic_curriculum(%TopicCurriculum{} = topic_curriculum, attrs) do
    topic_curriculum
    |> TopicCurriculum.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a topic_curriculum.
  ## Examples
      iex> delete_topic_curriculum(topic)
      {:ok, %TopicCurriculum{}}
      iex> delete_topic_curriculum(topic)
      {:error, %Ecto.Changeset{}}
  """
  def delete_topic_curriculum(%TopicCurriculum{} = topic_curriculum) do
    Repo.delete(topic_curriculum)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking topic_curriculum changes.
  ## Examples
      iex> change_topic_curriculum(topic_curriculum)
      %Ecto.Changeset{data: %TopicCurriculum{}}
  """
  def change_topic(%TopicCurriculum{} = topic_curriculum, attrs \\ %{}) do
    TopicCurriculum.changeset(topic_curriculum, attrs)
  end
end
