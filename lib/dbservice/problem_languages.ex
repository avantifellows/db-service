defmodule Dbservice.ProblemLanguages do
  @moduledoc """
  The ProblemLanguages context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Languages.Language
  alias Dbservice.Resources.ProblemLanguage

  @doc """
  Returns the list of problem_language.
  ## Examples
      iex> list_problem_language()
      [%ProblemLanguage{}, ...]
  """
  def list_problem_language do
    Repo.all(ProblemLanguage)
  end

  @doc """
  Gets a single problem_language.
  Raises `Ecto.NoResultsError` if the problem_language does not exist.
  ## Examples
      iex> get_problem_language!(123)
      %ProblemLanguage{}
      iex> get_problem_language!(456)
      ** (Ecto.NoResultsError)
  """
  def get_problem_language!(id), do: Repo.get!(ProblemLanguage, id)

  @doc """
  Gets a problem-language based on problem_id and language_id.
  Raises `Ecto.NoResultsError` if the ProblemLanguage does not exist.
  ## Examples
      iex> get_problem_language_by_problem_id_and_language_id(1, 2)
      %ProblemLanguage{}
      iex> get_problem_language_by_problem_id_and_language_id(abc)
      ** (Ecto.NoResultsError)
  """
  def get_problem_language_by_problem_id_and_language_id(problem_id, language_id) do
    Repo.get_by(ProblemLanguage, res_id: problem_id, lang_id: language_id)
  end

  @doc """
  Returns all language versions of a problem as a list of maps with
  `lang_code` and `meta_data`, one entry per `problem_lang` row.
  ## Examples
      iex> list_lang_versions_by_resource_id(1)
      [%{lang_code: "en", meta_data: %{...}}, %{lang_code: "hi", meta_data: %{...}}]
  """
  def list_lang_versions_by_resource_id(resource_id) do
    from(pl in ProblemLanguage,
      join: l in Language,
      on: l.id == pl.lang_id,
      where: pl.res_id == ^resource_id,
      order_by: [asc: pl.id],
      select: %{lang_code: l.code, meta_data: pl.meta_data}
    )
    |> Repo.all()
  end

  @doc """
  Batched version of `list_lang_versions_by_resource_id/1`. Fetches the
  language versions for many resources in a single query and returns a map of
  `resource_id => [%{lang_code, meta_data}]`. Use this instead of calling
  `list_lang_versions_by_resource_id/1` in a loop to avoid N+1 queries when
  rendering a list of problems.
  ## Examples
      iex> list_lang_versions_by_resource_ids([1, 2])
      %{1 => [%{lang_code: "en", meta_data: %{...}}], 2 => [...]}
  """
  def list_lang_versions_by_resource_ids([]), do: %{}

  def list_lang_versions_by_resource_ids(resource_ids) do
    from(pl in ProblemLanguage,
      join: l in Language,
      on: l.id == pl.lang_id,
      where: pl.res_id in ^resource_ids,
      order_by: [asc: pl.id],
      select: %{res_id: pl.res_id, lang_code: l.code, meta_data: pl.meta_data}
    )
    |> Repo.all()
    |> Enum.group_by(& &1.res_id, &Map.take(&1, [:lang_code, :meta_data]))
  end

  @doc """
  Creates a problem_language.
  ## Examples
      iex> create_problem_language(%{field: value})
      {:ok, %ProblemLanguage{}}
      iex> create_problem_language(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_problem_language(attrs \\ %{}) do
    %ProblemLanguage{}
    |> ProblemLanguage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a problem_language.
  ## Examples
      iex> update_problem_language(problem_language, %{field: new_value})
      {:ok, %ProblemLanguage{}}
      iex> update_problem_language(problem_language, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_problem_language(%ProblemLanguage{} = problem_language, attrs) do
    problem_language
    |> ProblemLanguage.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a problem_language.
  ## Examples
      iex> delete_problem_language(problem_language)
      {:ok, %ProblemLanguage{}}
      iex> delete_problem_language(problem_language)
      {:error, %Ecto.Changeset{}}
  """
  def delete_problem_language(%ProblemLanguage{} = problem_language) do
    Repo.delete(problem_language)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking problem_language changes.
  ## Examples
      iex> change_problem_language(problem_language)
      %Ecto.Changeset{data: %ProblemLanguage{}}
  """
  def change_problem_language(%ProblemLanguage{} = problem_language, attrs \\ %{}) do
    ProblemLanguage.changeset(problem_language, attrs)
  end
end
