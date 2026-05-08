defmodule DbserviceWeb.ResourceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Resources
  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Resources.ResourceCurriculum
  alias Dbservice.Topics.Topic
  alias Dbservice.TopicCurriculums.TopicCurriculum
  alias Dbservice.Chapters.Chapter
  alias Dbservice.Languages.Language
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Paragraphs
  alias Dbservice.Topics.Topic

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource(),
      SwaggerSchemaResource.resources()
    )
    |> Map.merge(SwaggerSchemaResource.problem_resource())
    |> Map.merge(SwaggerSchemaResource.move_resources())
    |> Map.merge(SwaggerSchemaResource.tests_containing_problems())
  end

  swagger_path :index do
    get("/api/resource")

    parameters do
      params(:query, :string, "The resource of the content",
        required: false,
        name: "name"
      )
    end

    response(200, "OK", Schema.ref(:Resources))
  end

  def index(conn, params) do
    resources = Resources.list_resources(params)
    render(conn, :index, resource: resources)
  end

  swagger_path :create do
    post("/api/resource")

    parameters do
      body(:body, Schema.ref(:Resource), "Resource to create", required: true)
    end

    response(201, "Created", Schema.ref(:Resource))
  end

  def get_subtypes(conn, %{"type" => type}) do
    subtypes = Resources.list_subtypes_by_type(type)
    json(conn, subtypes)
  end

  def create(conn, params) do
    type = params["type"]
    type_params = params["type_params"] || %{}

    case type do
      "test" -> handle_test_resource(conn, params)
      "video" -> handle_video_resource(conn, params, type_params)
      "problem" -> create_new_resource(conn, params)
      _ -> handle_default_resource(conn, params, type, type_params)
    end
  end

  defp handle_test_resource(conn, params) do
    code = params["code"]

    case Resources.get_resource_by_code(code) do
      nil -> create_new_resource(conn, params)
      existing_resource -> update_existing_resource(conn, existing_resource, params)
    end
  end

  defp handle_video_resource(conn, params, type_params) do
    link = type_params["src_link"]

    case Resources.get_resource_by_type_and_src_link("video", link) do
      nil -> create_new_resource(conn, params)
      existing_resource -> update_existing_resource(conn, existing_resource, params)
    end
  end

  defp handle_default_resource(conn, params, type, type_params) do
    case Resources.get_resource_by_type_and_type_params(type, type_params) do
      nil -> create_new_resource(conn, params)
      existing_resource -> update_existing_resource(conn, existing_resource, params)
    end
  end

  swagger_path :show do
    get("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(200, "OK", Schema.ref(:Resource))
  end

  def show(conn, %{"id" => id}) do
    resource = Resources.get_resource!(id)
    render(conn, :show, resource: resource)
  end

  swagger_path :update do
    patch("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
      body(:body, Schema.ref(:Resource), "Resource to create", required: true)
    end

    response(200, "Updated", Schema.ref(:Resource))
  end

  def update(conn, params) do
    resource = Resources.get_resource!(params["id"])

    with {:ok, %Resource{} = resource} <-
           Resources.update_resource_and_associations(resource, params) do
      render(conn, :show, resource: resource)
    end
  end

  swagger_path :move_resources do
    post("/api/resources/move")

    description(
      "Move one or more problems to a new curriculum/grade/subject/chapter/topic. Same body as PATCH resource but with resource_ids array."
    )

    parameters do
      body(:body, Schema.ref(:MoveResourcesRequest), "Resource IDs and target association params",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:MoveResourcesResponse))
  end

  swagger_path :tests_containing_problems do
    post("/api/resources/tests-containing-problems")

    description(
      "Returns which tests contain any of the given problem IDs. Use to check if selected problems can be moved (e.g. they are used in tests)."
    )

    parameters do
      body(:body, Schema.ref(:TestsContainingProblemsRequest), "List of problem (resource) IDs",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:TestsContainingProblemsResponse))
  end

  def tests_containing_problems(conn, params) do
    problem_ids = params["problem_ids"] || []

    if Enum.empty?(problem_ids) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "problem_ids is required and must be a non-empty array"})
    else
      results = Resources.get_tests_containing_problems(problem_ids)

      problem_tests =
        Enum.map(problem_ids, fn raw_id ->
          problem_id = normalize_id(raw_id)
          problem = problem_id && Repo.get(Resource, problem_id)
          problem_code = if problem, do: problem.code, else: nil

          tests_for_problem =
            results
            |> Enum.filter(fn %{problem_ids_in_test: pids} -> problem_id in pids end)
            |> Enum.map(fn %{test_id: id, test: test} ->
              %{
                test_id: id,
                test_code: test.code,
                name: format_resource_name(test.name)
              }
            end)
            |> Enum.uniq_by(& &1.test_id)

          %{
            problem_id: problem_id,
            problem_code: problem_code,
            tests: tests_for_problem
          }
        end)
        |> Enum.reject(fn %{problem_id: id} -> is_nil(id) end)

      conn
      |> put_status(:ok)
      |> json(%{problem_tests: problem_tests})
    end
  end

  defp normalize_id(id) when is_integer(id), do: id

  defp normalize_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp normalize_id(_), do: nil

  # Formats resource.name array to [%{lang_code: "en", resource: "..."}, ...]
  defp format_resource_name(nil), do: []

  defp format_resource_name(name) when is_list(name) do
    Enum.map(name, fn item ->
      item = item || %{}
      lang_code = item["lang_code"] || item["lang"] || item[:lang_code] || item[:lang]
      text = item["resource"] || item["value"] || item[:resource] || item[:value] || ""
      %{lang_code: lang_code, resource: text}
    end)
  end

  defp format_resource_name(_), do: []

  def move_resources(conn, params) do
    resource_ids = params["resource_ids"] || []
    # Association params only (no resource_ids)
    association_params = Map.drop(params, ["resource_ids"])

    if Enum.empty?(resource_ids) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "resource_ids is required and must be a non-empty array"})
    else
      result =
        Enum.reduce_while(resource_ids, {:ok, []}, fn id, {:ok, acc} ->
          resource = Resources.get_resource!(id)

          case Resources.update_resource_and_associations(resource, association_params) do
            {:ok, updated} -> {:cont, {:ok, [updated | acc]}}
            error -> {:halt, error}
          end
        end)

      case result do
        {:ok, resources} ->
          conn
          |> put_status(:ok)
          |> render(:index, resource: Enum.reverse(resources))

        {:error, %Ecto.Changeset{} = changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: DbserviceWeb.ChangesetJSON.translate_errors(changeset)})

        {:error, msg} when is_binary(msg) ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: msg})

        {:error, _} = err ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: inspect(err)})
      end
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/resource/{resourceId}")

    parameters do
      resourceId(:path, :integer, "The id of the resource record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    resource = Resources.get_resource!(id)

    with {:ok, %Resource{}} <- Resources.delete_resource(resource) do
      send_resp(conn, :no_content, "")
    end
  end

  defp create_new_resource(conn, params) do
    result =
      Repo.transaction(fn ->
        params =
          Map.put(params, "tag_ids", Dbservice.Resources.resolve_tag_ids(params["tags"] || []))

        handle_resource_creation_and_association(params)
      end)

    case result do
      {:ok, resource} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/resource/#{resource}")
        |> render(:show, resource: resource)

      {:error, {:changeset_error, changeset}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: DbserviceWeb.ChangesetJSON.translate_errors(changeset)})

      {:error, {:curriculum_error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create resource curriculum entries: #{inspect(reason)}"})

      {:error, {:cms_status_error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})

      {:error, {:comprehension_error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  defp handle_resource_creation_and_association(params) do
    case Resources.create_resource(params) do
      {:ok, %Resource{} = resource} ->
        resource = Resources.assign_code_after_insert(resource)
        handle_curriculum_and_related_inserts(resource, params)

      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback({:changeset_error, changeset})

      {:error, reason} ->
        Repo.rollback({:cms_status_error, reason})
    end
  end

  defp handle_curriculum_and_related_inserts(resource, params) do
    case Resources.create_resource_curriculums_for_resource(resource, params) do
      :ok ->
        insert_problem_language(resource, params)
        insert_resource_chapter(resource, params)
        insert_resource_topic(resource, params)
        insert_resource_concepts(resource, params)
        resource

      {:error, reason} ->
        Repo.rollback({:curriculum_error, reason})
    end
  end

  defp insert_problem_language(resource, %{"lang_code" => lang_code} = params)
       when not is_nil(lang_code) do
    if language = Repo.get_by(Language, code: lang_code) do
      case Paragraphs.problem_language_insert_attrs(resource, params, language.id) do
        {:ok, attrs} ->
          case Dbservice.ProblemLanguages.create_problem_language(attrs) do
            {:ok, _} -> :ok
            {:error, cs} -> Repo.rollback({:changeset_error, cs})
          end

        {:error, %Ecto.Changeset{} = cs} ->
          Repo.rollback({:changeset_error, cs})

        {:error, {:missing_paragraph_body, msg}} ->
          Repo.rollback({:comprehension_error, msg})
      end
    end
  end

  defp insert_problem_language(_, _), do: :ok

  defp insert_resource_chapter(resource, %{"chapter_id" => chapter_id})
       when not is_nil(chapter_id) do
    Dbservice.ResourceChapters.create_resource_chapter(%{
      resource_id: resource.id,
      chapter_id: chapter_id
    })
  end

  defp insert_resource_chapter(_, _), do: :ok

  defp insert_resource_topic(resource, %{"topic_id" => topic_id}) when not is_nil(topic_id) do
    Dbservice.ResourceTopics.create_resource_topic(%{
      resource_id: resource.id,
      topic_id: topic_id
    })
  end

  defp insert_resource_topic(_, _), do: :ok

  defp insert_resource_concepts(resource, %{"concept_ids" => concept_ids})
       when is_list(concept_ids) do
    Enum.each(concept_ids, fn concept_id ->
      Dbservice.ResourceConcepts.create_resource_concept(%{
        resource_id: resource.id,
        concept_id: concept_id
      })
    end)
  end

  defp insert_resource_concepts(_, _), do: :ok

  defp update_existing_resource(conn, existing_resource, params) do
    merged_params = merge_tag_ids(existing_resource, params)

    with {:ok, %Resource{} = resource} <-
           Resources.update_resource(existing_resource, merged_params) do
      conn
      |> put_status(:ok)
      |> render(:show, resource: resource)
    end
  end

  defp merge_tag_ids(existing_resource, params) do
    existing_tags = existing_resource.tag_ids || []
    new_tags = Map.get(params, "tag_ids") || []

    # Ensure unique tags, cast to integers if necessary
    merged_tags =
      (existing_tags ++ new_tags)
      # Normalize to integers
      |> Enum.map(&String.to_integer(to_string(&1)))
      |> Enum.uniq()

    Map.put(params, "tag_ids", merged_tags)
  end

  swagger_path :curriculum_resources do
    get("/api/resources/curriculum")

    parameters do
      curriculumId(
        :query,
        :integer,
        "The ID of the curriculum",
        required: true
      )

      gradeId(
        :query,
        :integer,
        "The ID of the grade (optional - if not provided, returns resources for all grades)",
        required: false
      )

      subjectId(
        :query,
        :integer,
        "The ID of the subject (optional)",
        required: false
      )

      chapterId(
        :query,
        :integer,
        "The ID of the chapter (optional)",
        required: false
      )

      topicId(
        :query,
        :integer,
        "The ID of the topic (optional)",
        required: false
      )

      type(
        :query,
        :string,
        "The type of resource (optional - e.g., 'video', 'test', 'problem')",
        required: false
      )

      subtype(
        :query,
        :string,
        "The subtype of resource (optional)",
        required: false
      )

      limit(
        :query,
        :integer,
        "Number of resources to return (optional)",
        required: false
      )

      offset(
        :query,
        :integer,
        "Number of resources to skip (optional)",
        required: false
      )
    end

    response(200, "OK", Schema.ref(:Resources))
  end

  def curriculum_resources(conn, params) do
    query =
      if topic_scoped_curriculum_request?(params) do
        build_topic_scoped_curriculum_query(params)
      else
        build_default_curriculum_resources_query(params)
      end

    query =
      query
      |> filter_by_type(params)
      |> filter_by_subtype(params)
      |> apply_pagination(params)

    resources = Repo.all(query)
    render(conn, "index.json", resource: resources)
  end

  defp topic_scoped_curriculum_request?(params),
    do: Map.get(params, "topic_id") not in [nil, ""]

  # In-curriculum if resource_curriculum matches OR topic_curriculum links this topic.
  defp build_topic_scoped_curriculum_query(params) do
    curriculum_id = param_as_integer!(params, "curriculum_id")
    topic_id = param_as_integer!(params, "topic_id")

    query =
      from(r in Resource,
        as: :resource,
        join: rt in ResourceTopic,
        on: rt.resource_id == r.id,
        join: t in Topic,
        on: t.id == rt.topic_id,
        where: rt.topic_id == ^topic_id,
        where:
          exists(
            from(rc in ResourceCurriculum,
              where:
                rc.resource_id == parent_as(:resource).id and rc.curriculum_id == ^curriculum_id
            )
          ) or
            exists(
              from(tc in TopicCurriculum,
                where: tc.topic_id == ^topic_id and tc.curriculum_id == ^curriculum_id
              )
            ),
        distinct: r.id,
        order_by: [asc: r.id]
      )

    query =
      case param_as_integer(params, "chapter_id") do
        nil -> query
        chapter_id -> from([r, rt, t] in query, where: t.chapter_id == ^chapter_id)
      end

    filter_topic_scoped_by_grade_and_subject(query, params)
  end

  defp build_default_curriculum_resources_query(params) do
    curriculum_id = param_as_integer!(params, "curriculum_id")

    from(r in Resource,
      join: rc in ResourceCurriculum,
      on: rc.resource_id == r.id,
      where: rc.curriculum_id == ^curriculum_id,
      distinct: r.id,
      order_by: [asc: r.id]
    )
    |> filter_by_grade(params)
    |> filter_by_subject(params)
    |> filter_by_chapter(params)
  end

  defp filter_topic_scoped_by_grade_and_subject(query, params) do
    grade_id = param_as_integer(params, "grade_id")
    subject_id = param_as_integer(params, "subject_id")

    case {grade_id, subject_id} do
      {nil, nil} ->
        query

      {g, s} ->
        dyn =
          case {g, s} do
            {g, nil} -> dynamic([_, _, _, ch], ch.grade_id == ^g)
            {nil, s} -> dynamic([_, _, _, ch], ch.subject_id == ^s)
            {g, s} -> dynamic([_, _, _, ch], ch.grade_id == ^g and ch.subject_id == ^s)
          end

        from([r, rt, t] in query,
          join: ch in Chapter,
          on: ch.id == t.chapter_id,
          where: ^dyn
        )
    end
  end

  defp param_as_integer(params, key) do
    case Map.get(params, key) do
      nil -> nil
      "" -> nil
      v when is_integer(v) -> v
      v when is_binary(v) -> String.to_integer(v)
    end
  end

  defp param_as_integer!(params, key) do
    case param_as_integer(params, key) do
      nil -> raise ArgumentError, "missing or invalid query param: #{key}"
      v -> v
    end
  end

  defp filter_by_subject(query, %{"subject_id" => subject_id})
       when not is_nil(subject_id) do
    from([r, rc] in query,
      where: rc.subject_id == ^subject_id
    )
  end

  defp filter_by_subject(query, _), do: query

  defp filter_by_chapter(query, %{"chapter_id" => chapter_id}) when not is_nil(chapter_id) do
    from(r in query,
      join: rch in ResourceChapter,
      on: rch.resource_id == r.id,
      where: rch.chapter_id == ^chapter_id
    )
  end

  defp filter_by_chapter(query, _), do: query

  defp filter_by_grade(query, %{"grade_id" => grade_id}) when not is_nil(grade_id) do
    from([r, rc] in query,
      where: rc.grade_id == ^grade_id
    )
  end

  defp filter_by_grade(query, _), do: query

  defp filter_by_type(query, %{"type" => type}) when not is_nil(type) do
    from(r in query, where: r.type == ^type)
  end

  defp filter_by_type(query, _), do: query

  defp filter_by_subtype(query, %{"subtype" => subtype}) when not is_nil(subtype) do
    from(r in query, where: r.subtype == ^subtype)
  end

  defp filter_by_subtype(query, _), do: query

  defp apply_pagination(query, params) do
    case Map.get(params, "limit") do
      nil ->
        query

      limit_str ->
        limit = String.to_integer(limit_str)

        offset =
          case Map.get(params, "offset") do
            nil -> 0
            offset_str -> String.to_integer(offset_str)
          end

        from(r in query, limit: ^limit, offset: ^offset)
    end
  end

  swagger_path :test_problems do
    get("/api/resource/test/{testId}/problems")

    parameters do
      testId(:path, :integer, "The ID of the test resource", required: true)

      langCode(
        :query,
        :string,
        "The code of the language to fetch problems in (e.g., 'en', 'hi')",
        required: true
      )

      curriculumId(
        :query,
        :integer,
        "The ID of the curriculum to get difficulty level",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:ProblemResource))
  end

  @doc """
  Returns all problems for a specific test in a specific language.

  GET /api/resource/test/:id/problems?lang_code=en&curriculum_id=1
  """
  def test_problems(conn, %{
        "id" => test_id,
        "lang_code" => lang_code,
        "curriculum_id" => curriculum_id
      }) do
    # Parse test ID and curriculum ID to integer
    test_id = String.to_integer(test_id)
    curriculum_id = String.to_integer(curriculum_id)

    result = Resources.get_problems_by_test_and_language(test_id, lang_code, curriculum_id)

    case result do
      {:error, :language_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Language with code '#{lang_code}' not found"})

      {:error, :test_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Test resource not found"})

      {:error, :resource_not_test_type} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The specified resource is not a test"})

      problems ->
        conn
        |> put_status(:ok)
        |> render("index.json", resource: problems)
    end
  end

  swagger_path :fetch_problems do
    get("/api/problems")
    summary("Fetch problems by topic, curriculum and language")
    description("Returns problems filtered by topic_id, curriculum_id and lang_code")

    parameters do
      topic_id(:query, :integer, "Topic ID", required: true)
      curriculum_id(:query, :integer, "Curriculum ID", required: true)
      lang_code(:query, :string, "Language code", required: true)
    end

    response(200, "OK", Schema.ref(:ProblemResource))
  end

  def fetch_problems(conn, %{
        "topic_id" => topic_id,
        "curriculum_id" => curriculum_id,
        "lang_code" => lang_code
      }) do
    language = Repo.get_by(Language, code: lang_code)

    if is_nil(language) do
      conn
      |> put_status(:not_found)
      |> json(%{error: "Language not found"})
    else
      # First build the query to get the correct resources
      query =
        from(r in Resource,
          join: rt in ResourceTopic,
          on: rt.resource_id == r.id,
          join: t in Topic,
          on: t.id == rt.topic_id,
          join: rc in ResourceCurriculum,
          on: rc.resource_id == r.id,
          join: pl in ProblemLanguage,
          on: pl.res_id == r.id,
          join: l in Language,
          on: l.id == pl.lang_id,
          where: rt.topic_id == ^topic_id,
          where: rc.curriculum_id == ^curriculum_id,
          where: l.code == ^lang_code,
          where: r.type == "problem",
          select: %{
            resource: r,
            resource_topic: rt,
            chapter_id: t.chapter_id,
            resource_curriculums: [rc],
            requested_curriculum_id: ^curriculum_id,
            problem_lang: pl
          }
        )

      problems = Repo.all(query)

      render(conn, "problems.json", problems: problems)
    end
  end

  swagger_path :get_problem do
    get("/api/resource/problem/{problem_id}/{lang_code}/{curriculum_id}")

    parameters do
      problem_id(:path, :integer, "The id of the problem resource", required: true)
      lang_code(:path, :string, "The language code", required: true)
      curriculum_id(:path, :integer, "The curriculum ID", required: true)
    end

    response(200, "OK", Schema.ref(:ProblemResource))
    response(404, "Not Found")
  end

  @doc """
  Get a specific problem by resource ID, language code and curriculum ID.

  This endpoint returns problem data by joining the resource and problem_lang tables
  based on the provided problem_id, lang_code and curriculum_id parameters.
  """
  def get_problem(conn, %{
        "problem_id" => res_id,
        "lang_code" => lang_code,
        "curriculum_id" => curriculum_id
      }) do
    query =
      from(p in ProblemLanguage,
        join: r in Resource,
        on: r.id == p.res_id,
        join: l in Language,
        on: l.id == p.lang_id,
        where: p.res_id == ^res_id and l.code == ^lang_code,
        preload: [resource: {r, [:resource_curriculum]}, language: l]
      )

    case Repo.one(query) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Problem not found for given inputs"})

      problem_lang ->
        resource_curriculum =
          Enum.find(problem_lang.resource.resource_curriculum, fn rc ->
            rc.curriculum_id == String.to_integer(curriculum_id)
          end)

        case resource_curriculum do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "No resource found for given curriculum_id"})

          rc ->
            render(conn, "problem_lang.json",
              resource: problem_lang.resource,
              meta_data: problem_lang.meta_data,
              lang_code: problem_lang.language.code,
              resource_curriculum: rc
            )
        end
    end
  end

  swagger_path :search_problems do
    get("/api/problems/search")

    parameters do
      query(:string, "search", "Search term to find in problem text, hint, or solution",
        required: false
      )

      query(:string, "type", "Resource type (e.g., 'problem')", required: false)

      query(:string, "subtype", "Resource subtype", required: false)

      query(:string, "lang_code", "Language code for the problem (e.g., 'en', 'hi')",
        required: false
      )

      query(:integer, "limit", "Number of results per page", required: false)

      query(:integer, "offset", "Number of results to skip", required: false)

      query(:string, "sort_by", "Field to sort by (e.g., 'subtype', 'text')", required: false)

      query(:string, "sort_order", "Sort order: 'asc' or 'desc'", required: false)

      query(:string, "subject_id", "Subject id of the Resource", required: false)
    end

    response(200, "OK")
  end

  def search_problems(conn, params) do
    # Ensure type is set to "problem" for problem search
    params = Map.put(params, "type", "problem")

    # Ensure default values for pagination
    params =
      params
      |> Map.put_new("limit", 10)
      |> Map.put_new("offset", 0)

    total_count = Resources.count_problems(params)
    problems = Resources.search_problems(params)

    conn
    |> put_resp_header("x-total-count", Integer.to_string(total_count))
    |> render("problems.json", problems: problems)
  end
end
