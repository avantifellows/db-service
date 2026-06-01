defmodule DbserviceWeb.LmsStudentDocumentJSON do
  def index(%{documents: documents}) do
    for(d <- documents, do: render(d))
  end

  def show(%{document: document}) do
    render(document)
  end

  def render(doc) do
    %{
      id: doc.id,
      student_id: doc.student_id,
      document_type: doc.document_type,
      pages: doc.pages,
      metadata: doc.metadata,
      uploaded_by: doc.uploaded_by,
      deleted_at: doc.deleted_at,
      inserted_at: doc.inserted_at,
      updated_at: doc.updated_at
    }
  end
end
