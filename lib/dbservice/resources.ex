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
  alias Dbservice.CmsStatuses
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Topics.Topic
  alias Dbservice.ChapterCurriculums

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
    language = from(l in Language, where: l.code == ^lang_code, select: l) |> Repo.one()

    case language do
      nil -> {:error, :language_not_found}
      %Language{id: lang_id} -> get_problems_for_test(test_id, lang_id, curriculum_id)
    end
  end

  defp get_problems_for_test(test_id, lang_id, curriculum_id) do
    test_resource = Repo.get(Resource, test_id)

    cond do
      is_nil(test_resource) -> {:error, :test_not_found}
      test_resource.type != "test" -> {:error, :resource_not_test_type}
      true -> fetch_and_format_problems(test_resource, lang_id, curriculum_id)
    end
  end

  defp fetch_and_format_problems(test_resource, lang_id, curriculum_id) do
    problem_ids = extract_problem_ids_from_test(test_resource.type_params)

    problems =
      from(r in Resource,
        where: r.id in ^problem_ids and r.type == "problem",
        preload: [
          :resource_curriculum,
          :chapter,
          problem_language: ^from(pl in ProblemLanguage, where: pl.lang_id == ^lang_id)
        ]
      )
      |> Repo.all()

    Enum.map(problems, fn resource ->
      problem_lang = Enum.find(resource.problem_language, &(&1.lang_id == lang_id))

      %{
        resource: resource,
        resource_curriculums: resource.resource_curriculum,
        problem_lang: problem_lang || %{},
        requested_curriculum_id: curriculum_id
      }
    end)
  end

  @doc """
  Extracts all problem IDs from a test's type_params structure.
  Keeps nesting depth at maximum of 2 levels.
  Handles both string and atom keys (Ecto/DB may return either from jsonb).
  """
  def extract_problem_ids_from_test(type_params) do
    type_params = ensure_map(type_params)
    # Some tests have "subjects" at top level; others nest under "type_params" (e.g. test id 4).
    subjects = get_attr(type_params, "subjects") || get_attr(type_params, :subjects)

    subjects =
      if is_nil(subjects) || subjects == [] do
        inner = get_attr(type_params, "type_params") || get_attr(type_params, :type_params)
        get_attr(ensure_map(inner), "subjects") || get_attr(ensure_map(inner), :subjects) || []
      else
        subjects
      end

    extract_problems_from_subjects(List.wrap(subjects))
  end

  defp extract_problems_from_subjects(subjects) when is_list(subjects) do
    Enum.flat_map(subjects, fn subject ->
      sections = get_attr(subject, "sections") || get_attr(subject, :sections) || []
      extract_problems_from_sections(List.wrap(sections))
    end)
  end

  defp extract_problems_from_subjects(_), do: []

  defp extract_problems_from_sections(sections) when is_list(sections) do
    Enum.flat_map(sections, fn section ->
      extract_problems_from_section(section)
    end)
  end

  defp extract_problems_from_sections(_), do: []

  defp extract_problems_from_section(section) do
    compulsory = get_attr(section, "compulsory") || get_attr(section, :compulsory) || %{}
    optional = get_attr(section, "optional") || get_attr(section, :optional) || %{}

    (problems_list_from_sub(compulsory) ++ problems_list_from_sub(optional))
    |> Enum.map(&problem_id_from_map/1)
    |> Enum.reject(&is_nil/1)
  end

  defp problems_list_from_sub(sub) do
    List.wrap(get_attr(sub, "problems") || get_attr(sub, :problems) || [])
  end

  defp problem_id_from_map(problem), do: get_attr(problem, "id") || get_attr(problem, :id)

  # Ensure we have a map (decode JSON string if needed).
  defp ensure_map(nil), do: %{}
  defp ensure_map(%{} = m), do: m

  defp ensure_map(bin) when is_binary(bin) do
    case Jason.decode(bin) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp ensure_map(_), do: %{}

  # Get map value by string or atom key (Ecto/DB may return either for jsonb).
  defp get_attr(map, _key) when not is_map(map), do: nil

  defp get_attr(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil when is_binary(key) ->
        try do
          Map.get(map, String.to_existing_atom(key))
        rescue
          ArgumentError -> nil
        end

      nil when is_atom(key) ->
        Map.get(map, Atom.to_string(key))

      val ->
        val
    end
  end

  @doc """
  Returns all tests that contain any of the given problem IDs.
  Used to determine if selected problems can be moved (e.g. if they are part of a test).

  ## Parameters
    - problem_ids: List of resource (problem) IDs to look up.

  ## Returns
    - List of maps: `%{test_id: id, test: %Resource{}, problem_ids_in_test: [ids]}` where
      `problem_ids_in_test` are the requested problem IDs that appear in that test.

  ## Examples
      iex> get_tests_containing_problems([5014, 5015])
      [%{test_id: 100, test: %Resource{}, problem_ids_in_test: [5014]}, ...]
  """
  def get_tests_containing_problems(problem_ids) when is_list(problem_ids) do
    requested_set =
      problem_ids
      |> Enum.map(&to_id/1)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    if MapSet.size(requested_set) == 0 do
      []
    else
      tests = from(r in Resource, where: r.type == "test", select: r) |> Repo.all()

      tests
      |> Enum.map(fn test ->
        test_problem_ids = extract_problem_ids_from_test(test.type_params || %{})

        contained =
          test_problem_ids
          |> Enum.map(&to_id/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(&MapSet.member?(requested_set, &1))
          |> Enum.uniq()

        {test, contained}
      end)
      |> Enum.reject(fn {_test, contained} -> contained == [] end)
      |> Enum.map(fn {test, contained} ->
        %{
          test_id: test.id,
          test: test,
          problem_ids_in_test: contained
        }
      end)
    end
  end

  defp to_id(id) when is_integer(id), do: id

  defp to_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp to_id(id), do: id

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
    with {:ok, attrs} <- CmsStatuses.ensure_cms_status_id(attrs) do
      %Resource{}
      |> Resource.changeset(attrs)
      |> Repo.insert()
    end
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
    with {:ok, attrs} <- CmsStatuses.ensure_cms_status_id(attrs) do
      resource
      |> Resource.changeset(attrs)
      |> Repo.update()
    end
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
    # Validate move params before any updates: topic must be under chapter, chapter under curriculum/grade/subject
    case validate_move_association_params(params) do
      :ok ->
        do_update_resource_and_associations(resource, params)

      {:error, _msg} = err ->
        err
    end
  end

  defp do_update_resource_and_associations(resource, params) do
    # Handle tags: resolve tag names to IDs if present
    params =
      if Map.has_key?(params, "tags") do
        Map.put(params, "tag_ids", resolve_tag_ids(params["tags"]))
      else
        params
      end

    result = update_resource(resource, params)

    case result do
      {:ok, resource} ->
        update_resource_associations(resource, params)
        {:ok, resource}

      error ->
        error
    end
  end

  # Validates that move params are consistent: topic belongs to chapter, chapter belongs to curriculum/grade/subject.
  # Returns :ok or {:error, message}.
  defp validate_move_association_params(params) do
    chapter_id = params["chapter_id"]
    topic_id = params["topic_id"]
    curriculum_grades = List.wrap(params["curriculum_grades"] || [])
    subject_id = params["subject_id"]

    with :ok <-
           validate_chapter_belongs_to_curriculum(
             chapter_id,
             topic_id,
             curriculum_grades,
             subject_id
           ) do
      validate_topic_belongs_to_chapter(topic_id, chapter_id)
    end
  end

  defp validate_chapter_belongs_to_curriculum(chapter_id, topic_id, curriculum_grades, subject_id) do
    has_curriculum_info = (curriculum_grades != [] || subject_id) && subject_id != nil

    if has_curriculum_info do
      chapter = resolve_chapter_for_validation(chapter_id, topic_id)

      validate_chapter_and_curriculum(
        chapter_id,
        topic_id,
        chapter,
        curriculum_grades,
        subject_id
      )
    else
      :ok
    end
  end

  defp resolve_chapter_for_validation(chapter_id, _topic_id)
       when not is_nil(chapter_id) and chapter_id != "" do
    id = normalize_chapter_topic_id(chapter_id)
    id && Repo.get(Chapter, id)
  end

  defp resolve_chapter_for_validation(_chapter_id, topic_id)
       when not is_nil(topic_id) and topic_id != "" do
    id = normalize_chapter_topic_id(topic_id)

    case id && Repo.get(Topic, id) do
      nil -> nil
      topic -> Repo.get(Chapter, topic.chapter_id)
    end
  end

  defp resolve_chapter_for_validation(_, _), do: nil

  defp normalize_chapter_topic_id(id) when is_integer(id), do: id

  defp normalize_chapter_topic_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp normalize_chapter_topic_id(_), do: nil

  defp validate_chapter_and_curriculum(
         chapter_id,
         topic_id,
         chapter,
         curriculum_grades,
         subject_id
       ) do
    case chapter_validation_error(chapter_id, topic_id, chapter, subject_id) do
      nil -> validate_chapter_curriculum_grades(chapter, curriculum_grades)
      err -> err
    end
  end

  defp chapter_validation_error(chapter_id, topic_id, chapter, subject_id) do
    chapter_lookup_error(chapter_id, topic_id, chapter) ||
      chapter_subject_error(chapter, subject_id)
  end

  defp chapter_lookup_error(chapter_id, topic_id, chapter) do
    cond do
      present?(chapter_id) && !chapter -> {:error, "Chapter not found"}
      present?(topic_id) && topic_not_found?(topic_id) -> {:error, "Topic not found"}
      !chapter -> {:error, "Topic's chapter not found"}
      true -> nil
    end
  end

  defp topic_not_found?(topic_id) do
    tid = normalize_chapter_topic_id(topic_id)
    is_nil(tid) || is_nil(Repo.get(Topic, tid))
  end

  defp chapter_subject_error(chapter, subject_id) do
    if chapter && chapter.subject_id != subject_id do
      {:error, "Chapter does not belong to the given subject"}
    else
      nil
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_), do: true

  defp validate_chapter_curriculum_grades(chapter, curriculum_grades) do
    result =
      Enum.reduce_while(curriculum_grades, :ok, fn cg, :ok ->
        validate_one_curriculum_grade(chapter, cg)
      end)

    if result == :ok, do: :ok, else: result
  end

  defp validate_one_curriculum_grade(chapter, cg) do
    grade_id = cg["grade_id"] || cg[:grade_id]
    curriculum_id = cg["curriculum_id"] || cg[:curriculum_id]

    cond do
      chapter.grade_id != grade_id ->
        {:halt, {:error, "Chapter does not belong to the given grade for curriculum"}}

      is_nil(
        ChapterCurriculums.get_chapter_curriculum_by_chapter_id_and_curriculum_id(
          chapter.id,
          curriculum_id
        )
      ) ->
        {:halt, {:error, "Chapter is not linked to the given curriculum"}}

      true ->
        {:cont, :ok}
    end
  end

  defp validate_topic_belongs_to_chapter(topic_id, chapter_id) do
    if present?(topic_id) and present?(chapter_id) do
      tid = normalize_chapter_topic_id(topic_id)
      cid = normalize_chapter_topic_id(chapter_id)

      if is_nil(tid) || is_nil(cid),
        do: {:error, "Invalid topic or chapter id"},
        else: do_validate_topic_belongs_to_chapter(tid, cid)
    else
      :ok
    end
  end

  defp do_validate_topic_belongs_to_chapter(topic_id, chapter_id) do
    case Repo.get(Topic, topic_id) do
      nil ->
        {:error, "Topic not found"}

      topic ->
        if topic.chapter_id == chapter_id,
          do: :ok,
          else: {:error, "Topic does not belong to the given chapter"}
    end
  end

  defp update_resource_associations(resource, params) do
    update_resource_curriculums(resource, params)
    update_resource_topic(resource, params)
    update_resource_chapter(resource, params)
    update_resource_concepts(resource, params)

    if resource.type == "problem" do
      update_problem_language(resource, params)
    end
  end

  # When curriculum_grades (and optionally subject_id) are present, replace all resource_curriculum
  # rows only if there is a change in at least one of curriculum, grade or subject.
  defp update_resource_curriculums(resource, params) do
    if Map.has_key?(params, "curriculum_grades") do
      curriculum_grades = List.wrap(params["curriculum_grades"] || [])
      subject_id = params["subject_id"]

      requested_set =
        curriculum_grades
        |> Enum.map(fn cg ->
          {cg["curriculum_id"] || cg[:curriculum_id], cg["grade_id"] || cg[:grade_id], subject_id}
        end)
        |> MapSet.new()

      current_rcs =
        Dbservice.ResourceCurriculums.list_resource_curriculums_by_resource_id(resource.id)

      current_set =
        current_rcs
        |> Enum.map(fn rc -> {rc.curriculum_id, rc.grade_id, rc.subject_id} end)
        |> MapSet.new()

      if requested_set != current_set do
        replace_resource_curriculums(resource, params, curriculum_grades, current_rcs)
      end
    end
  end

  defp replace_resource_curriculums(resource, params, curriculum_grades, current_rcs) do
    params = ensure_difficulty_level_in_params(params, current_rcs)

    from(rc in Dbservice.Resources.ResourceCurriculum, where: rc.resource_id == ^resource.id)
    |> Repo.delete_all()

    if not Enum.empty?(curriculum_grades) do
      create_resource_curriculums_for_resource(resource, params)
    end
  end

  defp ensure_difficulty_level_in_params(params, current_rcs) do
    if Map.has_key?(params, "difficulty_level") do
      params
    else
      case current_rcs do
        [rc | _] -> Map.put(params, "difficulty_level", rc.difficulty_level)
        [] -> params
      end
    end
  end

  defp update_resource_topic(resource, params) do
    if Map.has_key?(params, "topic_id") do
      requested_topic_id = params["topic_id"]

      current_topic_ids =
        from(rt in ResourceTopic, where: rt.resource_id == ^resource.id, select: rt.topic_id)
        |> Repo.all()
        |> MapSet.new()

      requested_set =
        if requested_topic_id, do: MapSet.new([requested_topic_id]), else: MapSet.new()

      if requested_set != current_topic_ids do
        from(rt in ResourceTopic, where: rt.resource_id == ^resource.id)
        |> Repo.delete_all()

        if requested_topic_id do
          Dbservice.ResourceTopics.create_resource_topic(%{
            "resource_id" => resource.id,
            "topic_id" => requested_topic_id
          })
        end
      end
    end
  end

  defp update_resource_chapter(resource, params) do
    if Map.has_key?(params, "chapter_id") do
      requested_chapter_id = params["chapter_id"]

      current_chapter_ids =
        from(rch in ResourceChapter,
          where: rch.resource_id == ^resource.id,
          select: rch.chapter_id
        )
        |> Repo.all()
        |> MapSet.new()

      requested_set =
        if requested_chapter_id, do: MapSet.new([requested_chapter_id]), else: MapSet.new()

      if requested_set != current_chapter_ids do
        from(rch in ResourceChapter, where: rch.resource_id == ^resource.id)
        |> Repo.delete_all()

        if requested_chapter_id do
          Dbservice.ResourceChapters.create_resource_chapter(%{
            "resource_id" => resource.id,
            "chapter_id" => requested_chapter_id
          })
        end
      end
    end
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
    if not Enum.empty?(concepts_to_remove) do
      from(rc in ResourceConcept,
        where: rc.resource_id == ^resource.id and rc.concept_id in ^concepts_to_remove
      )
      |> Repo.delete_all()
    end

    # Add new concepts
    if not Enum.empty?(concepts_to_add) do
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

  defp get_offset(params), do: params["offset"]
  defp get_limit(params), do: params["limit"]

  @doc """
  Searches for problems with optional filtering, sorting and pagination.
  Searches in problem_lang table and includes resource + resource_curriculum details.

  ## Examples

      iex> search_problems(%{"search" => "che", "limit" => 10, "offset" => 0, "sort_by" => "subtype", "sort_order" => "asc"})
      [%{resource: %Resource{}, problem_lang: %ProblemLanguage{}, resource_curriculums: [%ResourceCurriculum{}]}, ...]

      iex> count_problems(%{"search" => "che"})
      25
  """
  def search_problems(params \\ %{}) do
    ProblemLanguage
    |> from(as: :pl)
    |> apply_problem_search_filters(params)
    |> apply_problem_sorting(params)
    |> apply_problem_pagination(params)
    |> Repo.all()
    |> Enum.map(fn problem_lang ->
      resource = Repo.get!(Resource, problem_lang.res_id)

      resource_curriculums =
        Repo.all(
          from(rc in Dbservice.Resources.ResourceCurriculum,
            where: rc.resource_id == ^resource.id
          )
        )

      %{
        resource: resource,
        problem_lang: problem_lang,
        resource_curriculums: resource_curriculums
      }
    end)
  end

  def count_problems(params \\ %{}) do
    ProblemLanguage
    |> from(as: :pl)
    |> apply_problem_search_filters(params)
    |> select([pl], count(pl.id))
    |> Repo.one()
  end

  # Private query building functions for problem search

  defp apply_problem_search_filters(query, params) do
    Enum.reduce(params, query, &apply_problem_search_filter/2)
  end

  defp apply_problem_search_filter({"search", value}, query)
       when not is_nil(value) and value != "" do
    search_term = "%#{value}%"

    from(pl in query,
      join: r in Resource,
      on: pl.res_id == r.id,
      where:
        r.type == "problem" and
          (ilike(r.code, ^search_term) or
             ilike(fragment("?->>'text'", pl.meta_data), ^search_term) or
             ilike(fragment("?->>'hint'", pl.meta_data), ^search_term) or
             ilike(fragment("?->>'solution'", pl.meta_data), ^search_term))
    )
  end

  defp apply_problem_search_filter({"type", value}, query) when not is_nil(value) do
    from(pl in query,
      join: r in Resource,
      on: pl.res_id == r.id,
      where: r.type == ^value
    )
  end

  defp apply_problem_search_filter({"subtype", value}, query) when not is_nil(value) do
    from(pl in query,
      join: r in Resource,
      on: pl.res_id == r.id,
      where: r.subtype == ^value
    )
  end

  defp apply_problem_search_filter({"lang_code", value}, query)
       when not is_nil(value) and value != "" do
    from(pl in query,
      join: l in Language,
      on: pl.lang_id == l.id,
      where: l.code == ^value
    )
  end

  defp apply_problem_search_filter({"subject_id", value}, query)
       when not is_nil(value) and value != "" do
    from(q in query,
      where:
        exists(
          from(rc in Dbservice.Resources.ResourceCurriculum,
            where:
              rc.resource_id == parent_as(:pl).res_id and
                rc.subject_id == ^value
          )
        )
    )
  end

  defp apply_problem_search_filter({key, _value}, query)
       when key in ["offset", "limit", "sort_by", "sort_order"] do
    query
  end

  defp apply_problem_search_filter({_key, _value}, query) do
    query
  end

  defp apply_problem_sorting(query, params) do
    sort_by = params["sort_by"]
    sort_order = get_sort_order(params["sort_order"])

    case sort_by do
      "code" ->
        from(pl in query,
          join: r in Resource,
          on: pl.res_id == r.id,
          order_by: [{^sort_order, r.code}],
          select: pl
        )

      "subtype" ->
        from(pl in query,
          join: r in Resource,
          on: pl.res_id == r.id,
          order_by: [{^sort_order, r.subtype}],
          select: pl
        )

      "text" ->
        from(pl in query,
          order_by: [{^sort_order, fragment("?->>'text'", pl.meta_data)}]
        )

      _ ->
        # Default sorting by id
        from(pl in query, order_by: [asc: pl.id])
    end
  end

  defp apply_problem_pagination(query, params) do
    from(pl in query,
      offset: ^get_offset(params),
      limit: ^get_limit(params)
    )
  end
end
