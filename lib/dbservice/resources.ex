defmodule Dbservice.Resources do
  @moduledoc """
  The Resources context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Languages.Language
  alias Dbservice.Resources.{ResourceTopic, ResourceChapter, ResourceConcept}
  alias Dbservice.Utils.Util

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

          # Query for all problems with those IDs, including ALL resource_curriculum data and chapter data
          problems =
            from(r in Resource,
              where: r.id in ^problem_ids and r.type == "problem",
              preload: [
                # preload all curriculum mappings
                :resource_curriculum,
                # preload chapters via the many_to_many association
                :chapter,
                # keyword preload must come last in the list
                problem_language: ^from(pl in ProblemLanguage, where: pl.lang_id == ^lang_id)
              ]
            )
            |> Repo.all()

          Enum.map(problems, fn resource ->
            problem_lang = Enum.find(resource.problem_language, &(&1.lang_id == lang_id))

            %{
              resource: resource,
              # always a list
              resource_curriculums: resource.resource_curriculum,
              problem_lang: problem_lang || %{},
              requested_curriculum_id: curriculum_id
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
  Creates multiple ResourceCurriculum entries for a given resource using a params map.

  - `resource`: The resource struct.
  - `params`: Map expected to contain:
      - "curriculum_grades": List of maps, each with "curriculum_id" and "grade_id".
      - "subject_id": The subject_id to use for all entries (global for this resource).
      - "difficulty_level": The difficulty_level to use for all entries (global for this resource).

  Each ResourceCurriculum will be created with the same subject_id and difficulty_level.
  """
  def create_resource_curriculums_for_resource(resource, params) when is_map(params) do
    curriculum_grades = Map.get(params, "curriculum_grades", [])
    subject_id = Map.get(params, "subject_id")
    difficulty_level = Map.get(params, "difficulty_level")

    Enum.reduce_while(curriculum_grades, :ok, fn %{
                                                   "curriculum_id" => curriculum_id,
                                                   "grade_id" => grade_id
                                                 },
                                                 _acc ->
      attrs = %{
        resource_id: resource.id,
        curriculum_id: curriculum_id,
        grade_id: grade_id,
        subject_id: subject_id,
        difficulty_level: difficulty_level
      }

      case Dbservice.ResourceCurriculums.create_resource_curriculum(attrs) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def create_resource_curriculums_for_resource(_resource, _params), do: :ok

  @doc """
  Generates a resource code in the format P{7digitcode} (e.g., P0000024) using the resource's ID.
  """
  def generate_next_resource_code(id) when is_integer(id) do
    "P" <> String.pad_leading(Integer.to_string(id), 7, "0")
  end

  def update_resource_and_associations(resource, params) do
    # Handle tags: resolve tag names to IDs if present
    params =
      if Map.has_key?(params, "tags") do
        Map.put(params, "tag_ids", resolve_tag_ids(params["tags"]))
      else
        params
      end

    # Update the resource itself
    result = update_resource(resource, params)

    # If update successful, handle associations
    case result do
      {:ok, resource} ->
        update_resource_associations(resource, params)
        {:ok, resource}

      error ->
        error
    end
  end

  defp update_resource_associations(resource, params) do
    update_resource_curriculums(resource, params)
    update_resource_concepts(resource, params)

    if resource.type == "problem" do
      update_problem_language(resource, params)
    end
  end

  defp update_resource_curriculums(resource, params) do
    Enum.each(List.wrap(params["curriculum_grades"] || []), fn cg ->
      rc =
        Dbservice.ResourceCurriculums.get_resource_curriculum_by_resource_id_and_curriculum_id(
          resource.id,
          cg["curriculum_id"]
        )

      if rc, do: Dbservice.ResourceCurriculums.update_resource_curriculum(rc, params)
    end)
  end

  defp update_problem_language(resource, params) do
    lang = Dbservice.Languages.get_language_by_code(params["lang_code"])
    lang_id = lang && lang.id

    if lang_id do
      pl =
        Dbservice.ProblemLanguages.get_problem_language_by_problem_id_and_language_id(
          resource.id,
          lang_id
        )

      if pl, do: Dbservice.ProblemLanguages.update_problem_language(pl, params)
    end
  end

  def resolve_tag_ids(tags) do
    Enum.map(tags, &resolve_tag_id/1)
  end

  def resolve_tag_id(tag) when is_integer(tag), do: tag

  def resolve_tag_id(tag) when is_binary(tag) do
    case Dbservice.Tags.get_tag_by_name(tag) do
      nil ->
        {:ok, new_tag} = Dbservice.Tags.create_tag(%{"name" => tag})
        new_tag.id

      tag_struct ->
        tag_struct.id
    end
  end

  def resolve_tag_id(tag), do: tag

  defp update_resource_concepts(resource, %{"concept_ids" => new_concept_ids})
       when is_list(new_concept_ids) do
    # Get current concept IDs
    current_concept_ids =
      from(rc in ResourceConcept, where: rc.resource_id == ^resource.id, select: rc.concept_id)
      |> Repo.all()

    # Find concepts to add and remove
    concepts_to_add = new_concept_ids -- current_concept_ids
    concepts_to_remove = current_concept_ids -- new_concept_ids

    # Remove concepts
    if length(concepts_to_remove) > 0 do
      from(rc in ResourceConcept,
        where: rc.resource_id == ^resource.id and rc.concept_id in ^concepts_to_remove
      )
      |> Repo.delete_all()
    end

    # Add new concepts
    if length(concepts_to_add) > 0 do
      resource_concepts_to_insert =
        Enum.map(concepts_to_add, fn concept_id ->
          %{
            resource_id: resource.id,
            concept_id: concept_id,
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      Repo.insert_all(ResourceConcept, resource_concepts_to_insert)
    end
  end

  defp update_resource_concepts(_, _), do: :ok

  @doc """
  Lists resources with optional filtering, sorting and pagination.

  ## Examples

      iex> list_resources(%{})
      [%Resource{}, ...]

      iex> list_resources(%{"search" => "elixir", "limit" => 10, "sort_by" => "code", "sort_order" => "desc"})
      [%Resource{}, ...]
  """
  def list_resources(params \\ %{}) do
    Resource
    |> apply_filters(params)
    |> apply_language_filter(params)
    |> apply_sorting(params)
    |> apply_pagination(params)
    |> Repo.all()
  end

  @doc """
  Counts resources matching the given filters.
  """
  def count_resources(params \\ %{}) do
    Resource
    |> apply_filters(params)
    |> apply_language_filter(params)
    |> select([r], count(r.id))
    |> Repo.one()
  end

  # Private query building functions

  defp apply_filters(query, params) do
    Enum.reduce(params, query, &apply_filter/2)
  end

  defp apply_filter({"topic_id", value}, query) when not is_nil(value) do
    from(r in query,
      join: rt in ResourceTopic,
      on: rt.resource_id == r.id,
      where: rt.topic_id == ^value
    )
  end

  defp apply_filter({"chapter_id", value}, query) when not is_nil(value) do
    from(r in query,
      join: rc in ResourceChapter,
      on: rc.resource_id == r.id,
      where: rc.chapter_id == ^value
    )
  end

  defp apply_filter({"search", value}, query) when not is_nil(value) and value != "" do
    search_term = "%#{value}%"

    from(r in query,
      where:
        ilike(r.code, ^search_term) or
          fragment(
            "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE LOWER(obj->>'resource') LIKE LOWER(?))",
            r.name,
            ^search_term
          )
    )
  end

  defp apply_filter({key, _value}, query)
       when key in ["offset", "limit", "lang_code", "sort_by", "sort_order"] do
    query
  end

  defp apply_filter({key, value}, query) do
    apply_field_filter(query, key, value)
  end

  defp apply_field_filter(query, "name", value) when not is_nil(value) do
    from(r in query,
      where:
        fragment(
          "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'resource' = ?)",
          r.name,
          ^value
        )
    )
  end

  defp apply_field_filter(query, "resource_type", value) when not is_nil(value) do
    from(r in query,
      where: fragment("?->>'resource_type' = ?", r.type_params, ^value)
    )
  end

  defp apply_field_filter(query, key, value) when not is_nil(value) do
    try do
      field_atom = String.to_existing_atom(key)
      from(r in query, where: field(r, ^field_atom) == ^value)
    rescue
      ArgumentError -> query
    end
  end

  defp apply_field_filter(query, _key, _value), do: query

  defp apply_language_filter(query, params) do
    Util.filter_by_lang(query, params)
  end

  defp apply_sorting(query, params) do
    sort_by = params["sort_by"]
    sort_order = get_sort_order(params["sort_order"])

    case sort_by do
      "code" ->
        from(r in query, order_by: [{^sort_order, r.code}])

      "name" ->
        # Sort by the first element's 'resource' field in the name JSONB array
        from(r in query,
          order_by: [
            {^sort_order,
             fragment(
               "LOWER((JSONB_ARRAY_ELEMENTS(?) -> 'resource')::text)",
               r.name
             )}
          ]
        )

      # TBD: Implement sorting by curriculum and grade

      # "curriculum" ->
      #   from(r in query,
      #     left_join: rc in assoc(r, :resource_curriculum),
      #     left_join: c in Dbservice.Curriculums.Curriculum,
      #     on: rc.curriculum_id == c.id,
      #     order_by: [{^sort_order, c.name}],
      #     distinct: r.id
      #   )

      # "grade" ->
      #   from(r in query,
      #     left_join: rc in assoc(r, :resource_curriculum),
      #     left_join: g in Dbservice.Grades.Grade,
      #     on: rc.grade_id == g.id,
      #     order_by: [{^sort_order, g.number}],
      #     distinct: r.id
      #   )

      "subtype" ->
        from(r in query, order_by: [{^sort_order, r.subtype}])

      _ ->
        # Default sorting by id
        from(r in query, order_by: [asc: r.id])
    end
  end

  defp get_sort_order("desc"), do: :desc
  defp get_sort_order("DESC"), do: :desc
  defp get_sort_order(_), do: :asc

  defp apply_pagination(query, params) do
    from(r in query,
      offset: ^get_offset(params),
      limit: ^get_limit(params)
    )
  end

  defp get_offset(params), do: params["offset"] || 0
  defp get_limit(params), do: params["limit"] || 50
end
