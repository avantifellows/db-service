defmodule DbserviceWeb.FormSchemaController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.FormSchemas
  alias Dbservice.FormSchemas.FormSchema

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.FormSchema, as: SwaggerSchemaFormSchema

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaFormSchema.form_schema(),
      SwaggerSchemaFormSchema.form_schemas()
    )
  end

  swagger_path :index do
    get("/api/form-schema?name=Registration")
    response(200, "OK", Schema.ref(:FormSchemas))
  end

  def index(conn, params) do
    query =
      from(m in FormSchema,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          atom -> from(u in acc, where: field(u, ^atom) == ^value)
        end
      end)

    form_schema = Repo.all(query)
    render(conn, "index.json", form_schema: form_schema)
  end

  swagger_path :create do
    post("/api/form-schema")

    parameters do
      body(:body, Schema.ref(:FormSchema), "Form Schema to create", required: true)
    end

    response(201, "Created", Schema.ref(:FormSchema))
  end

  def create(conn, params) do
    with {:ok, %FormSchema{} = form_schema} <- FormSchemas.create_form_schema(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.form_schema_path(conn, :show, form_schema))
      |> render("show.json", form_schema: form_schema)
    end
  end

  swagger_path :show do
    get("/api/form-schema/{formSchemaId}")

    parameters do
      formSchemaId(:path, :integer, "The id of the form schema record", required: true)
    end

    response(200, "OK", Schema.ref(:FormSchema))
  end

  def show(conn, %{"id" => id}) do
    form_schema = FormSchemas.get_form_schema!(id)
    render(conn, "show.json", form_schema: form_schema)
  end

  swagger_path :update do
    patch("/api/form-schema/{formSchemaId}")

    parameters do
      formSchemaId(:path, :integer, "The id of the form schema record", required: true)
      body(:body, Schema.ref(:FormSchema), "Form schema to create", required: true)
    end

    response(200, "Updated", Schema.ref(:FormSchema))
  end

  def update(conn, params) do
    form_schema = FormSchemas.get_form_schema!(params["id"])

    with {:ok, %FormSchema{} = form_schema} <- FormSchemas.update_form_schema(form_schema, params) do
      render(conn, "show.json", form_schema: form_schema)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/form_schema/{formSchemaId}")

    parameters do
      formSchemaId(:path, :integer, "The id of the form schema record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    form_schema = FormSchemas.get_form_schema!(id)

    with {:ok, %FormSchema{}} <- FormSchemas.delete_form_schema(form_schema) do
      send_resp(conn, :no_content, "")
    end
  end
end
