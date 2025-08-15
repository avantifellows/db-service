defmodule Dbservice.Subjects do
  @moduledoc """
  The Subjects context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo
  alias Dbservice.Utils.Util

  alias Dbservice.Subjects.Subject

  @doc """
  Returns the list of subject.
  ## Examples
      iex> list_subject()
      [%Subject{}, ...]
  """
  def list_subject do
    Repo.all(Subject)
  end

  @doc """
  Gets a single subject.
  Raises `Ecto.NoResultsError` if the subject does not exist.
  ## Examples
      iex> get_subject!(123)
      %Subject{}
      iex> get_subject!(456)
      ** (Ecto.NoResultsError)
  """
  def get_subject!(id), do: Repo.get!(Subject, id)

  @doc """
  Gets a subject by name, searching in the JSONB name array for English language entries.

  The name field is now a JSONB array of objects like:
  [{"subject": "English", "lang_code": "en"}, {"subject": null, "lang_code": "hi"}]

  This function uses the filter_by_lang utility to filter by English language entries,
  then searches for the given subject name (case-insensitive).

  ## Examples

      iex> get_subject_by_name("botany")
      %Subject{}

      iex> get_subject_by_name("Botany")
      %Subject{}

      iex> get_subject_by_name("nonexistent")
      nil

  """
  def get_subject_by_name(name) when is_binary(name) do
    base_query = from(s in Subject)

    # Use filter_by_lang to filter for English entries only
    filtered_query = Util.filter_by_lang(base_query, %{"lang_code" => "en"})

    # Then filter by the subject name (case-insensitive) within the filtered English entries
    from(s in filtered_query,
      where:
        fragment(
          "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE LOWER(obj->>'subject') = LOWER(?))",
          s.name,
          ^name
        )
    )
    |> Repo.one()
  end

  def get_subject_by_name(_), do: nil

  @doc """
  Creates a subject.
  ## Examples
      iex> create_subject(%{field: value})
      {:ok, %Subject{}}
      iex> create_subject(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_subject(attrs \\ %{}) do
    %Subject{}
    |> Subject.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subject.
  ## Examples
      iex> update_subject(subject, %{field: new_value})
      {:ok, %Subject{}}
      iex> update_subject(subject, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_subject(%Subject{} = subject, attrs) do
    subject
    |> Subject.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subject.
  ## Examples
      iex> delete_subject(subject)
      {:ok, %Subject{}}
      iex> delete_subject(subject)
      {:error, %Ecto.Changeset{}}
  """
  def delete_subject(%Subject{} = subject) do
    Repo.delete(subject)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking subject changes.
  ## Examples
      iex> change_subject(subject)
      %Ecto.Changeset{data: %Subject{}}
  """
  def change_subject(%Subject{} = subject, attrs \\ %{}) do
    Subject.changeset(subject, attrs)
  end
end
