defmodule Dbservice.JacDelhiCutoff2023 do
  @derive {Jason.Encoder, only: [
    :id, :institute, :academic_program_name, :category, :gender, :defense, :pwd,
    :state, :category_key, :closing_rank, :inserted_at, :updated_at
  ]}
  use Ecto.Schema
  import Ecto.Changeset

  schema "jac_delhi_cutoff_2023" do
    field :institute, :string
    field :academic_program_name, :string
    field :category, :string
    field :gender, :string
    field :defense, :boolean, default: false
    field :pwd, :boolean, default: false
    field :state, :string
    field :category_key, :string
    field :closing_rank, :integer
    timestamps()
  end

  def changeset(jac, attrs) do
    jac
    |> cast(attrs, [:institute, :academic_program_name, :category, :gender, :defense, :pwd, :state, :category_key, :closing_rank])
    |> validate_required([:institute, :academic_program_name, :category, :gender, :defense, :pwd, :state, :category_key, :closing_rank])
  end
end
