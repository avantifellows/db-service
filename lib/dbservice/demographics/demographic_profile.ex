defmodule Dbservice.Demographics.DemographicProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "demographic_profile" do
    field :category_id, :integer
    field :gender, :string
    field :caste, :string
    field :pwd, :string
    field :income, :string
    field :religion, :string
    field :defence_ward, :string
    field :nationality, :string
    field :ews_ward, :string
    field :language, :string
    field :urban_rural, :string
    field :region, :string

    has_many :cutoffs, Dbservice.Cutoffs.Cutoff, foreign_key: :category_id

    timestamps()
  end

  @doc false
  def changeset(demographic_profile, attrs) do
    demographic_profile
    |> cast(attrs, [
      :category_id,
      :gender,
      :caste,
      :pwd,
      :income,
      :religion,
      :defence_ward,
      :nationality,
      :ews_ward,
      :language,
      :urban_rural,
      :region
    ])
    |> validate_required([:category_id])
  end
end
