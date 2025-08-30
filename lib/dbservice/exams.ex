defmodule Dbservice.Exams do
  @moduledoc """
  The Exams context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Exams.Exam
  alias Dbservice.Exams.ExamOccurrence

  @doc """
  Returns the list of exams.
  ## Examples
      iex> list_exam()
      [%Exam{}, ...]
  """
  def list_exam do
    Repo.all(Exam)
  end

  @doc """
  Gets a single exam.
  Raises `Ecto.NoResultsError` if the Exam does not exist.
  ## Examples
      iex> get_exam!(123)
      %Exam{}
      iex> get_exam!(456)
      ** (Ecto.NoResultsError)
  """
  def get_exam!(id) do
    Repo.get!(Exam, id)
  end

  @doc """
  Gets a single exam with exam_occurrences preloaded.
  Raises `Ecto.NoResultsError` if the Exam does not exist.
  ## Examples
      iex> get_exam_with_occurrences!(123)
      %Exam{exam_occurrences: [%ExamOccurrence{}, ...]}
      iex> get_exam_with_occurrences!(456)
      ** (Ecto.NoResultsError)
  """
  def get_exam_with_occurrences!(id) do
    Exam
    |> Repo.get!(id)
    |> Repo.preload(:exam_occurrences)
  end

  @doc """
  Gets a Exam by exam_name.
  Raises `Ecto.NoResultsError` if the Exam does not exist.
  ## Examples
      iex> get_exam_by_name("NEET")
      %Exam{}
      iex> get_exam_by_name("Non-existent")
      nil
  """
  def get_exam_by_name(exam_name) do
    Repo.get_by(Exam, exam_name: exam_name)
  end

  @doc """
  Creates a exam.
  ## Examples
      iex> create_exam(%{field: value})
      {:ok, %Exam{}}
      iex> create_exam(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_exam(attrs \\ %{}) do
    %Exam{}
    |> Exam.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a exam.
  ## Examples
      iex> update_exam(exam, %{field: new_value})
      {:ok, %Exam{}}
      iex> update_exam(exam, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_exam(%Exam{} = exam, attrs) do
    exam
    |> Exam.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a exam.
  ## Examples
      iex> delete_exam(exam)
      {:ok, %Exam{}}
      iex> delete_exam(exam)
      {:error, %Ecto.Changeset{}}
  """
  def delete_exam(%Exam{} = exam) do
    Repo.delete(exam)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exam changes.
  ## Examples
      iex> change_exam(exam)
      %Ecto.Changeset{data: %Exam{}}
  """
  def change_exam(%Exam{} = exam, attrs \\ %{}) do
    Exam.changeset(exam, attrs)
  end

  def get_exams_by_ids(ids) when is_list(ids) do
    import Ecto.Query

    Dbservice.Exams.Exam
    |> where([exam], exam.id in ^ids)
    |> Dbservice.Repo.all()
  end

  def get_exams_by_ids(_), do: []

  # ExamOccurrence functions

  @doc """
  Returns the list of exam_occurrences.
  ## Examples
      iex> list_exam_occurrence()
      [%ExamOccurrence{}, ...]
  """
  def list_exam_occurrence do
    Repo.all(ExamOccurrence)
  end

  @doc """
  Gets a single exam_occurrence.
  Raises `Ecto.NoResultsError` if the ExamOccurrence does not exist.
  ## Examples
      iex> get_exam_occurrence!(123)
      %ExamOccurrence{}
      iex> get_exam_occurrence!(456)
      ** (Ecto.NoResultsError)
  """
  def get_exam_occurrence!(id) do
    Repo.get!(ExamOccurrence, id)
  end

  @doc """
  Gets exam occurrences by exam_id.
  ## Examples
      iex> get_exam_occurrences_by_exam_id(1)
      [%ExamOccurrence{}, ...]
  """
  def get_exam_occurrences_by_exam_id(exam_id) do
    ExamOccurrence
    |> where([eo], eo.exam_id == ^exam_id)
    |> Repo.all()
  end

  @doc """
  Creates an exam_occurrence.
  ## Examples
      iex> create_exam_occurrence(%{field: value})
      {:ok, %ExamOccurrence{}}
      iex> create_exam_occurrence(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_exam_occurrence(attrs \\ %{}) do
    %ExamOccurrence{}
    |> ExamOccurrence.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an exam_occurrence.
  ## Examples
      iex> update_exam_occurrence(exam_occurrence, %{field: new_value})
      {:ok, %ExamOccurrence{}}
      iex> update_exam_occurrence(exam_occurrence, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_exam_occurrence(%ExamOccurrence{} = exam_occurrence, attrs) do
    exam_occurrence
    |> ExamOccurrence.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an exam_occurrence.
  ## Examples
      iex> delete_exam_occurrence(exam_occurrence)
      {:ok, %ExamOccurrence{}}
      iex> delete_exam_occurrence(exam_occurrence)
      {:error, %Ecto.Changeset{}}
  """
  def delete_exam_occurrence(%ExamOccurrence{} = exam_occurrence) do
    Repo.delete(exam_occurrence)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking exam_occurrence changes.
  ## Examples
      iex> change_exam_occurrence(exam_occurrence)
      %Ecto.Changeset{data: %ExamOccurrence{}}
  """
  def change_exam_occurrence(%ExamOccurrence{} = exam_occurrence, attrs \\ %{}) do
    ExamOccurrence.changeset(exam_occurrence, attrs)
  end
end
