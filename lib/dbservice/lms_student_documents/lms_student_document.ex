defmodule Dbservice.LmsStudentDocuments.LmsStudentDocument do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  # The confirmation page an exam portal issues once an application form is
  # submitted. It is the one document type tied to an exam registration, and it
  # must be: an acknowledgement with no registration says nothing about which
  # exam it acknowledges.
  @exam_acknowledgement "exam_acknowledgement"

  schema "lms_student_documents" do
    field :document_type, :string
    field :pages, {:array, :map}, default: []
    field :metadata, :map, default: %{}
    field :uploaded_by, :string
    field :deleted_at, :naive_datetime
    # The sitting this document belongs to, for an exam that runs in sessions;
    # NULL for an exam that runs once.
    field :exam_session, :integer

    belongs_to :student, Dbservice.Users.Student
    belongs_to :student_exam_record, Dbservice.Exams.StudentExamRecord

    timestamps()
  end

  def exam_acknowledgement, do: @exam_acknowledgement

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :student_id,
      :document_type,
      :pages,
      :metadata,
      :uploaded_by,
      :deleted_at,
      :student_exam_record_id,
      :exam_session
    ])
    |> validate_required([:student_id, :document_type, :pages, :uploaded_by])
    |> validate_length(:document_type, min: 1, max: 64)
    |> validate_pages()
    |> validate_exam_link()
    |> foreign_key_constraint(:student_exam_record_id)
    |> check_constraint(:exam_session, name: :lms_student_documents_exam_session_check)
    |> unique_constraint(:student_exam_record_id,
      name: :lms_student_documents_active_exam_slot_index,
      message: "already has a current document for this session"
    )
  end

  # An exam acknowledgement needs its registration, and only an
  # acknowledgement may carry one. Whether the registration belongs to the same
  # student and offers that sitting needs the database, so it is checked by
  # `Dbservice.LmsStudentDocuments` before the insert.
  defp validate_exam_link(changeset) do
    type = get_field(changeset, :document_type)
    record_id = get_field(changeset, :student_exam_record_id)
    session = get_field(changeset, :exam_session)

    cond do
      type == @exam_acknowledgement and is_nil(record_id) ->
        add_error(
          changeset,
          :student_exam_record_id,
          "is required for an exam acknowledgement"
        )

      type != @exam_acknowledgement and not is_nil(record_id) ->
        add_error(
          changeset,
          :student_exam_record_id,
          "is only allowed on an exam acknowledgement"
        )

      type != @exam_acknowledgement and not is_nil(session) ->
        add_error(
          changeset,
          :exam_session,
          "is only allowed on an exam acknowledgement"
        )

      true ->
        changeset
    end
  end

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
