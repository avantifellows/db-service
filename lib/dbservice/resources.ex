defmodule Dbservice.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Languages.Language
  alias Dbservice.Resources.ResourceCurriculum

  @doc """
  Returns the list of resource.
  ## Examples
      iex> list_resource()
      [%Resource{}, ...]
  """
  def list_resource do
    Repo.all(Resource)
  end

  @doc """
  Gets a single resource.
  Raises `Ecto.NoResultsError` if the resource does not exist.
  ## Examples
      iex> get_resource!(123)
      %Resource{}
      iex> get_resource!(456)
      ** (Ecto.NoResultsError)
  """
  def get_resource!(id), do: Repo.get!(Resource, id)

  @doc """
  Gets all problems for a specific test in a specific language.

  ## Parameters
    - test_id: ID of the test resource
    - lang_code: Code of the language to fetch problems in (e.g., "en", "hi")
    - curriculum_id: ID of the curriculum to get difficulty level

  ## Returns
    - List of problem resources with their metadata from problem_lang table and difficulty_level from resource_curriculum
  """
  def get_problems_by_test_and_language(test_id, lang_code, curriculum_id) do
    # Get the language by code
    language =
      from(l in Language, where: l.code == ^lang_code, select: l)
      |> Repo.one()

    case language do
      nil ->
        {:error, :language_not_found}

      %Language{id: lang_id} ->
        with %Resource{} = test_resource <- Repo.get(Resource, test_id),
             true <- test_resource.type == "test" do
          problem_ids = extract_problem_ids_from_test(test_resource.type_params)

          # Query for all problems with those IDs, including resource_curriculum data
          problems =
            from(r in Resource,
              where: r.id in ^problem_ids and r.type == "problem",
              preload: [
                resource_curriculum:
                  ^from(rc in ResourceCurriculum, where: rc.curriculum_id == ^curriculum_id),
                problem_language: ^from(pl in ProblemLanguage, where: pl.lang_id == ^lang_id)
              ]
            )
            |> Repo.all()

          Enum.map(problems, fn resource ->
            # Get the correct resource_curriculum and problem_language for this curriculum/lang
            resource_curriculum =
              Enum.find(resource.resource_curriculum, &(&1.curriculum_id == curriculum_id))

            problem_lang = Enum.find(resource.problem_language, &(&1.lang_id == lang_id))

            %{
              resource: resource,
              resource_curriculum: resource_curriculum || %{},
              problem_lang: problem_lang || %{}
            }
          end)
        else
          nil -> {:error, :test_not_found}
          false -> {:error, :resource_not_test_type}
          error -> error
        end
    end
  end

  @doc """
  Extracts all problem IDs from a test's type_params structure.
  Keeps nesting depth at maximum of 2 levels.
  """
  def extract_problem_ids_from_test(type_params) do
    subjects = Map.get(type_params, "subjects", [])
    extract_problems_from_subjects(subjects)
  end

  defp extract_problems_from_subjects(subjects) do
    Enum.flat_map(subjects, fn subject ->
      sections = Map.get(subject, "sections", [])
      extract_problems_from_sections(sections)
    end)
  end

  defp extract_problems_from_sections(sections) do
    Enum.flat_map(sections, fn section ->
      extract_problems_from_section(section)
    end)
  end

  defp extract_problems_from_section(section) do
    compulsory_problems = get_in(section, ["compulsory", "problems"]) || []
    optional_problems = get_in(section, ["optional", "problems"]) || []

    (compulsory_problems ++ optional_problems)
    |> Enum.map(fn problem -> Map.get(problem, "id") end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Returns a list of unique subtypes for a given type.

  ## Examples

      iex> list_subtypes_by_type("test")
      ["subtype1", "subtype2", "subtype3"]

      iex> list_subtypes_by_type("nonexistent")
      []
  """
  def list_subtypes_by_type(type) do
    query =
      from(r in Resource,
        where: r.type == ^type and not is_nil(r.subtype),
        select: r.subtype,
        distinct: true,
        order_by: r.subtype
      )

    Repo.all(query)
  end

  @doc """
  Gets a resource by name and sourceId.

  Raises `Ecto.NoResultsError` if the School does not exist.

  ## Examples

      iex> get_resource_by_type_and_type_params("abc",{"src_link": "youtube"})
      %Resource{}

      iex> get_resource_by_type_and_type_params("abc", {"src_link": "youtube"})
      ** (Ecto.NoResultsError)

  """
  def get_resource_by_type_and_type_params(type, type_params) do
    Repo.get_by(Resource, type: type, type_params: type_params)
  end

  @doc """
  Gets a resource by type and src_link from type_params.
  Returns nil if not found.
  """
  def get_resource_by_type_and_src_link(type, src_link) do
    query =
      from(r in Resource,
        where: r.type == ^type and fragment("?->>'src_link' = ?", r.type_params, ^src_link)
      )

    Repo.one(query)
  end

  @doc """
  Gets a resource by code.
  Returns nil if not found.
  """
  def get_resource_by_code(code) do
    Repo.get_by(Resource, code: code)
  end

  @doc """
  Creates a resource.
  ## Examples
      iex> create_resource(%{field: value})
      {:ok, %Resource{}}
      iex> create_resource(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_resource(attrs \\ %{}) do
    %Resource{}
    |> Resource.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a resource.
  ## Examples
      iex> update_resource(resource, %{field: new_value})
      {:ok, %Resource{}}
      iex> update_resource(resource, %{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def update_resource(%Resource{} = resource, attrs) do
    resource
    |> Resource.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a resource.
  ## Examples
      iex> delete_resource(resource)
      {:ok, %Resource{}}
      iex> delete_resource(resource)
      {:error, %Ecto.Changeset{}}
  """
  def delete_resource(%Resource{} = resource) do
    Repo.delete(resource)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking resource changes.
  ## Examples
      iex> change_resource(resource)
      %Ecto.Changeset{data: %Resource{}}
  """
  def change_resource(%Resource{} = resource, attrs \\ %{}) do
    Resource.changeset(resource, attrs)
  end

  @doc """
  Creates multiple `ResourceCurriculum` entries for a given resource based on the provided curriculum grades.

  This function takes a resource and a list of curriculum grades, and attempts to create a `ResourceCurriculum` entry for each item in the list. Each entry links the resource to a specific curriculum and grade.

  ## Parameters

    - `resource`: The resource for which the curriculum entries are being created. This should be a `%Resource{}` struct that has been successfully created and contains an `id`.

    - `curriculum_grades`: A list of maps, where each map contains:
      - `"curriculum_id"`: The ID of the curriculum to associate with the resource.
      - `"grade_id"`: The ID of the grade to associate with the resource.

  ## Returns

    - `:ok` if all `ResourceCurriculum` entries are created successfully.

    - `{:error, reason}` if any of the entries fail to be created, where `reason` is the error returned by the `create_resource_curriculum` function.

  ## Examples

      iex> create_resource_curriculums_for_resource(resource, [%{"curriculum_id" => 1, "grade_id" => 1}, %{"curriculum_id" => 2, "grade_id" => 2}])
      :ok

      iex> create_resource_curriculums_for_resource(resource, [%{"curriculum_id" => 1, "grade_id" => 1}, %{"curriculum_id" => 2, "grade_id" => nil}])
      {:error, changeset}
  """
  def create_resource_curriculums_for_resource(resource, curriculum_grades)
      when is_list(curriculum_grades) do
    Enum.reduce_while(curriculum_grades, :ok, fn %{
                                                   "curriculum_id" => cur_id,
                                                   "grade_id" => grade_id
                                                 },
                                                 _acc ->
      case Dbservice.ResourceCurriculums.create_resource_curriculum(%{
             resource_id: resource.id,
             curriculum_id: cur_id,
             grade_id: grade_id
           }) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def create_resource_curriculums_for_resource(_resource, _curriculum_grades), do: :ok

  @doc """
  Generates a resource code in the format P{7digitcode} (e.g., P0000024) using the resource's ID.
  """
  def generate_next_resource_code(id) when is_integer(id) do
    "P" <> String.pad_leading(Integer.to_string(id), 7, "0")
  end
end
