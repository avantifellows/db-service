defmodule Dbservice.Subjects.Subject do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  # alias Dbservice.Tags.Tag
  alias Dbservice.Chapters.Chapter

  schema "subject" do
    field(:name, {:array, :map})
    field(:code, :string)
    field(:parent_id, :integer)

    timestamps()

    has_many(:chapter, Chapter)
    # belongs_to(:tag, Tag)
  end

  @doc false
  def changeset(subject, attrs) do
    subject
    |> cast(attrs, [
      :name,
      :code,
      :parent_id
      # :tag_id
    ])
  end
end
