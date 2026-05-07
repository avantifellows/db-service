defmodule DbserviceWeb.ParagraphController do
  use DbserviceWeb, :controller

  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Paragraphs
  alias Dbservice.Resources.Paragraph

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.Paragraph, as: SwaggerSchemaParagraph

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaParagraph.paragraph(),
      SwaggerSchemaParagraph.paragraphs()
    )
  end

  swagger_path :index do
    get("/api/paragraph")

    response(200, "OK", Schema.ref(:Paragraphs))
  end

  def index(conn, params) do
    query =
      from(m in Paragraph,
        order_by: [asc: m.id],
        offset: ^params["offset"],
        limit: ^params["limit"]
      )

    query =
      Enum.reduce(params, query, fn {key, _value}, acc ->
        case String.to_existing_atom(key) do
          :offset -> acc
          :limit -> acc
          _atom -> acc
        end
      end)

    paragraph = Repo.all(query)
    render(conn, :index, paragraph: paragraph)
  end

  swagger_path :create do
    post("/api/paragraph")

    parameters do
      body(:body, Schema.ref(:Paragraph), "Paragraph to create", required: true)
    end

    response(201, "Created", Schema.ref(:Paragraph))
  end

  def create(conn, params) do
    with {:ok, %Paragraph{} = paragraph} <- Paragraphs.create_paragraph(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/paragraph/#{paragraph}")
      |> render(:show, Paragraphs.get_paragraph_with_problem_lang!(paragraph.id))
    end
  end

  swagger_path :show do
    get("/api/paragraph/{paragraphId}")

    parameters do
      paragraphId(:path, :integer, "The id of the paragraph record", required: true)
    end

    response(200, "OK", Schema.ref(:Paragraph))
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, Paragraphs.get_paragraph_with_problem_lang!(id))
  end

  swagger_path :update do
    patch("/api/paragraph/{paragraphId}")

    parameters do
      paragraphId(:path, :integer, "The id of the paragraph record", required: true)
      body(:body, Schema.ref(:Paragraph), "Paragraph to update", required: true)
    end

    response(200, "Updated", Schema.ref(:Paragraph))
  end

  def update(conn, params) do
    paragraph = Paragraphs.fetch_paragraph!(params["id"])

    with {:ok, %Paragraph{} = paragraph} <- Paragraphs.update_paragraph(paragraph, params) do
      render(conn, :show, Paragraphs.get_paragraph_with_problem_lang!(paragraph.id))
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/paragraph/{paragraphId}")

    parameters do
      paragraphId(:path, :integer, "The id of the paragraph record", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    paragraph = Paragraphs.fetch_paragraph!(id)

    with {:ok, %Paragraph{}} <- Paragraphs.delete_paragraph(paragraph) do
      send_resp(conn, :no_content, "")
    end
  end
end
