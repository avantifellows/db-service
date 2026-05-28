defmodule DbserviceWeb.LmsStudentDocumentController do
  use DbserviceWeb, :controller

  alias Dbservice.LmsStudentDocuments
  alias Dbservice.LmsStudentDocuments.LmsStudentDocument

  action_fallback(DbserviceWeb.FallbackController)

  use PhoenixSwagger

  alias DbserviceWeb.SwaggerSchema.LmsStudentDocument, as: SwaggerSchemaLmsStudentDocument

  def swagger_definitions do
    Map.merge(
      SwaggerSchemaLmsStudentDocument.lms_student_document(),
      SwaggerSchemaLmsStudentDocument.lms_student_documents()
    )
  end

  swagger_path :index do
    get("/api/lms-student-document")

    parameters do
      student_id(:query, :integer, "Filter by student id", required: false)
      document_type(:query, :string, "Filter by document type", required: false)
    end

    response(200, "OK", Schema.ref(:LmsStudentDocuments))
  end

  def index(conn, params) do
    documents = LmsStudentDocuments.list_lms_student_documents(params)
    render(conn, :index, documents: documents)
  end

  swagger_path :create do
    post("/api/lms-student-document")

    parameters do
      body(:body, Schema.ref(:LmsStudentDocument), "Document to create", required: true)
    end

    response(201, "Created", Schema.ref(:LmsStudentDocument))
  end

  def create(conn, params) do
    with {:ok, %LmsStudentDocument{} = doc} <-
           LmsStudentDocuments.create_lms_student_document(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/lms-student-document/#{doc}")
      |> render(:show, document: doc)
    end
  end

  swagger_path :show do
    get("/api/lms-student-document/{id}")

    parameters do
      id(:path, :integer, "The id of the document", required: true)
    end

    response(200, "OK", Schema.ref(:LmsStudentDocument))
  end

  def show(conn, %{"id" => id}) do
    case LmsStudentDocuments.get_lms_student_document(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Document not found"})

      doc ->
        render(conn, :show, document: doc)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/api/lms-student-document/{id}")

    parameters do
      id(:path, :integer, "The id of the document", required: true)
    end

    response(204, "No Content")
  end

  def delete(conn, %{"id" => id}) do
    case LmsStudentDocuments.get_lms_student_document(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Document not found"})

      doc ->
        with {:ok, %LmsStudentDocument{}} <-
               LmsStudentDocuments.soft_delete_lms_student_document(doc) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
