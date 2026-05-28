defmodule Dbservice.LmsStudentDocuments.LmsStudentDocument do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @document_types ~w(research_consent id_proof bonafide other)

  schema "lms_student_documents" do
    field :document_type, :string
    field :pages, {:array, :map}, default: []
    field :metadata, :map, default: %{}
    field :uploaded_by, :string
    field :deleted_at, :naive_datetime

    belongs_to :student, Dbservice.Users.Student

    timestamps()
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :student_id,
      :document_type,
      :pages,
      :metadata,
      :uploaded_by,
      :deleted_at
    ])
    |> validate_required([:student_id, :document_type, :pages, :uploaded_by])
    |> validate_inclusion(:document_type, @document_types)
    |> validate_pages()
  end

  def document_types, do: @document_types

  defp validate_pages(changeset) do
    case get_field(changeset, :pages) do
      pages when is_list(pages) and pages == [] ->
        add_error(changeset, :pages, "must contain at least one page")

      pages when is_list(pages) ->
        if Enum.all?(pages, &valid_page?/1) do
          changeset
        else
          add_error(
            changeset,
            :pages,
            "each page must have s3_key, page_number, mime_type, byte_size"
          )
        end

      _ ->
        add_error(changeset, :pages, "must be a list")
    end
  end

  defp valid_page?(%{} = page) do
    is_binary(page["s3_key"] || page[:s3_key]) and
      is_integer(page["page_number"] || page[:page_number]) and
      is_binary(page["mime_type"] || page[:mime_type]) and
      is_integer(page["byte_size"] || page[:byte_size])
  end

  defp valid_page?(_), do: false
end
