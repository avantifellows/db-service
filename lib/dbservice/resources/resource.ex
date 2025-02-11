defmodule Dbservice.Resources.Resource do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.Teacher

  schema "resource" do
    field(:name, {:array, :map})
    field(:type, :string)
    field(:type_params, :map)
    field(:subtype, :string)
    field(:source, :string)
    field(:code, :string)
    field(:purpose_ids, {:array, :integer})
    field(:tag_ids, {:array, :integer})
    field(:skill_ids, {:array, :integer})
    field(:learning_objective_ids, {:array, :integer})

    timestamps()

    belongs_to(:teacher, Teacher)
  end

  @doc false
  def changeset(resource, attrs) do
    resource
    |> cast(attrs, [
      :name,
      :type,
      :type_params,
      :subtype,
      :source,
      :code,
      :purpose_ids,
      :tag_ids,
      :skill_ids,
      :learning_objective_ids,
      :teacher_id
    ])
    |> validate_required([:name, :type])
  end
end
