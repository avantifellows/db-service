defmodule Dbservice.Curriculums.Curriculum do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "curriculum" do
    field(:name, :string)
    field(:code, :string)

    timestamps()
  end

  @doc false
  def changeset(curriculum, attrs) do
    curriculum
    |> cast(attrs, [
      :name,
      :code
    ])
  end
end
