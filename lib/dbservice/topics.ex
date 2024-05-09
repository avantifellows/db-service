defmodule Dbservice.Topics do
  @moduledoc """
  The Topics context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Topics.Topic

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
