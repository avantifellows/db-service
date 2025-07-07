defmodule DbserviceWeb.ResourceController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Resources
  alias Dbservice.Resources.Resource
  alias Dbservice.Resources.ResourceTopic
  alias Dbservice.Resources.ResourceChapter
  alias Dbservice.Resources.ResourceCurriculum
  alias Dbservice.Utils.Util
  alias Dbservice.Languages.Language
  alias Dbservice.Resources.ProblemLanguage
  alias Dbservice.Tags

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource(),
      SwaggerSchemaResource.resources()
    )
    |> Map.merge(SwaggerSchemaResource.problem_resource())
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
    base_query =
      from(m in Resource,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, base_query, fn
        {"topic_id", value}, acc ->
          from(u in acc,
            join: rt in ResourceTopic,
            on: rt.resource_id == u.id,
            where: rt.topic_id == ^value
          )

        {"chapter_id", value}, acc ->
          from(u in acc,
            join: rc in ResourceChapter,
            on: rc.resource_id == u.id,
            where: rc.chapter_id == ^value
          )

        {key, value}, acc ->
          case String.to_existing_atom(key) do
            :offset ->
              acc

            :limit ->
              acc

            :lang_code ->
              acc

            :name ->
              from(u in acc,
                where:
                  fragment(
                    "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'resource' = ?)",
                    u.name,
                    ^value
                  )
              )

            :resource_type ->
              from(u in acc,
                where: fragment("?->>'resource_type' = ?", u.type_params, ^value)
              )

            atom ->
              from(u in acc, where: field(u, ^atom) == ^value)
          end
      end)

    # Language filtering
    query = Util.filter_by_lang(query, params)

    resource = Repo.all(query)
    render(conn, "index.json", resource: resource)
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
    render(conn, "show.json", resource: resource)
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

    with {:ok, %Resource{} = resource} <- Resources.update_resource(resource, params) do
      render(conn, "show.json", resource: resource)
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
        params = Map.put(params, "tag_ids", resolve_tag_ids(params["tags"] || []))
        handle_resource_creation_and_association(params)
      end)

    case result do
      {:ok, resource} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", Routes.resource_path(conn, :show, resource))
        |> render("show.json", resource: resource)

      {:error, {:changeset_error, changeset}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: DbserviceWeb.ChangesetView.translate_errors(changeset)})

      {:error, {:curriculum_error, reason}} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to create resource curriculum entries: #{inspect(reason)}"})
    end
  end

  defp handle_resource_creation_and_association(params) do
    case Resources.create_resource(params) do
      {:ok, %Resource{} = resource} ->
        resource = update_code_if_problem(resource)
        handle_curriculum_and_related_inserts(resource, params)

      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback({:changeset_error, changeset})
    end
  end

  defp update_code_if_problem(resource) do
    if resource.type == "problem" do
      code = Resources.generate_next_resource_code(resource.id)
      {:ok, updated_resource} = Resources.update_resource(resource, %{code: code})
      updated_resource
    else
      resource
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

  defp resolve_tag_ids(tags) do
    Enum.map(tags, &resolve_tag_id/1)
  end

  defp resolve_tag_id(tag) when is_integer(tag), do: tag

  defp resolve_tag_id(tag) when is_binary(tag) do
    case Tags.get_tag_by_name(tag) do
      nil ->
        {:ok, new_tag} = Tags.create_tag(%{"name" => tag})
        new_tag.id

      tag_struct ->
        tag_struct.id
    end
  end

  defp resolve_tag_id(tag), do: tag

  defp insert_problem_language(resource, %{"lang_code" => lang_code} = params)
       when not is_nil(lang_code) do
    if language = Repo.get_by(Language, code: lang_code) do
      Dbservice.ProblemLanguages.create_problem_language(%{
        res_id: resource.id,
        lang_id: language.id,
        meta_data: Map.get(params, "meta_data")
      })
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
      |> render("show.json", resource: resource)
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

  def curriculum_resources(conn, params) do
    query =
      from(r in Resource,
        join: rc in ResourceCurriculum,
        on: rc.resource_id == r.id,
        where:
          rc.curriculum_id == ^params["curriculum_id"] and rc.grade_id == ^params["grade_id"],
        order_by: [asc: r.id]
      )

    query =
      query
      |> filter_by_subject(params)
      |> filter_by_type(params)
      |> filter_by_subtype(params)
      |> apply_pagination(params)

    resources = Repo.all(query)
    render(conn, "index.json", resource: resources)
  end

  # Helper functions for each filter
  defp filter_by_subject(query, %{"subject_id" => subject_id})
       when not is_nil(subject_id) do
    from(r in query,
      join: rc in ResourceCurriculum,
      on: rc.resource_id == r.id,
      where: rc.subject_id == ^subject_id
    )
  end

  defp filter_by_subject(query, _), do: query

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

      {:error, :curriculum_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Curriculum not found"})

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
            resource_curriculum: rc,
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
      from p in ProblemLanguage,
        join: r in Resource,
        on: r.id == p.res_id,
        join: l in Language,
        on: l.id == p.lang_id,
        where: p.res_id == ^res_id and l.code == ^lang_code,
        preload: [resource: {r, [:resource_curriculum]}, language: l]

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
end
