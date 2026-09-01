defmodule Dbservice.CmsStatuses.CmsStatus do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "cms_status" do
    field :name, :string

    timestamps()

    has_many :resource, Dbservice.Resources.Resource
    has_many :chapter, Dbservice.Chapters.Chapter
    has_many :topic, Dbservice.Topics.Topic
  end

  @doc false
  def changeset(cms_status, attrs) do
    cms_status
    |> cast(attrs, [
      :name
    ])
    |> validate_required([:name])
    # Safety net for the DB-level unique index on name (cms_status_name_index):
    # translates a duplicate-name insert into an {:error, changeset} (→ 422) rather
    # than letting Ecto.ConstraintError bubble up as an unhandled 500 (issue #694).
    |> unique_constraint(:name)
  end
end
