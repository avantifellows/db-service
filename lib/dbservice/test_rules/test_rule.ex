defmodule Dbservice.TestRules.TestRule do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "test_rule" do
    field :test_type, :string
    field :config, :map
    belongs_to :exam, Dbservice.Exams.Exam, foreign_key: :exam_id

    timestamps()
  end

  @doc false
  def changeset(test_rule, attrs) do
    test_rule
    |> cast(attrs, [
      :exam_id,
      :test_type,
      :config
    ])
    |> validate_required([:exam_id, :test_type])
  end
end
