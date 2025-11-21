defmodule Dbservice.Demographics.DemographicProfile do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "demographic_profile" do
    field :category, :string
    field :gender, :string
    field :caste, :string
    field :physically_handicapped, :boolean, default: false
    field :family_income, :string
    field :religion, :string
    field :defence_ward, :string
    field :nationality, :string
    field :ews_ward, :string
    field :language, :string
    field :urban_rural, :boolean, default: false
    field :region, :string

    has_many :cutoffs, Dbservice.Cutoffs.Cutoff

    timestamps()
  end

  @doc false
  def changeset(demographic_profile, attrs) do
    demographic_profile
    |> cast(attrs, [
      :category,
      :gender,
      :caste,
      :physically_handicapped,
      :family_income,
      :religion,
      :defence_ward,
      :nationality,
      :ews_ward,
      :language,
      :urban_rural,
      :region
    ])
    |> validate_required([:category])
  end
end
