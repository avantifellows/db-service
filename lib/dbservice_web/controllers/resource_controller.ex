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

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Resource, as: SwaggerSchemaResource

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaResource.resource(),
      SwaggerSchemaResource.resources()
    )
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
    case Resources.get_resource_by_type_and_type_params(params["type"], params["type_params"]) do
      nil ->
        create_new_resource(conn, params)

      existing_resource ->
        update_existing_resource(conn, existing_resource, params)
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
    with {:ok, %Resource{} = resource} <- Resources.create_resource(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.resource_path(conn, :show, resource))
      |> render("show.json", resource: resource)
    end
  end

  defp update_existing_resource(conn, existing_resource, params) do
    with {:ok, %Resource{} = resource} <-
           Resources.update_resource(existing_resource, params) do
      conn
      |> put_status(:ok)
      |> render("show.json", resource: resource)
    end
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
      langId(:query, :integer, "The ID of the language to fetch problems in", required: true)
    end

    response(200, "OK", Schema.array(:Resource))
  end

  @doc """
  Returns all problems for a specific test in a specific language.

  GET /api/resource/test/:id/problems?lang_id=1
  """
  def test_problems(conn, %{"id" => test_id, "lang_id" => lang_id}) do
    # Parse IDs to integers
    test_id = String.to_integer(test_id)
    lang_id = String.to_integer(lang_id)

    result = Resources.get_problems_by_test_and_language(test_id, lang_id)

    case result do
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
end
