defmodule Dbservice.CmsStatuses.CmsStatus do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "cms_status" do
    field :name, :string

    timestamps()

    has_many :resource, Dbservice.Resources.Resource
  end

  @doc false
  def changeset(cms_status, attrs) do
    cms_status
    |> cast(attrs, [
      :name
    ])
    |> validate_required([:name])
  end
end
