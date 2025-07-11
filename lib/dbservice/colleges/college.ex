# model

defmodule Dbservice.Colleges.College do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "college" do
    field :college_id, :string
    field :name, :string
    field :state, :string
    field :address, :string
    field :district_code, :string
    field :gender_type, :string
    field :college_type, :string
    field :management_type, :string
    field :year_established, :integer
    field :affiliated_to, :string
    field :tuition_fee, :decimal
    field :af_hierarchy, :decimal
    field :expected_salary, :decimal
    field :salary_tier, :string
    field :qualifying_exam, :string
    field :nirf_ranking, :integer
    field :top_200_nirf, :boolean

    timestamps()
  end

  @doc false
  def changeset(college, attrs) do
    college
    |> cast(attrs, [
      :college_id,
      :name,
      :state,
      :address,
      :district_code,
      :gender_type,
      :college_type,
      :management_type,
      :year_established,
      :affiliated_to,
      :tuition_fee,
      :af_hierarchy,
      :expected_salary,
      :salary_tier,
      :qualifying_exam,
      :nirf_ranking,
      :top_200_nirf
    ])
    |> validate_required([:college_id, :name])
  end
end
