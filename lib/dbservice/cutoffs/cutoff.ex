defmodule Dbservice.Cutoffs.Cutoff do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "cutoffs" do
    field :cutoff_year, :integer
    field :degree, :string
    field :state_quota, :string
    field :opening_rank, :integer
    field :closing_rank, :integer

    belongs_to :exam_occurrence, Dbservice.Exams.ExamOccurrence
    belongs_to :college, Dbservice.Colleges.College
    belongs_to :branch, Dbservice.Branches.Branch
    belongs_to :demographic_profile, Dbservice.Demographics.DemographicProfile

    timestamps()
  end

  @doc false
  def changeset(cutoff, attrs) do
    cutoff
    |> cast(attrs, [
      :cutoff_year,
      :exam_occurrence_id,
      :college_id,
      :degree,
      :branch_id,
      :demographic_profile_id,
      :state_quota,
      :opening_rank,
      :closing_rank
    ])
    |> validate_required([
      :cutoff_year,
      :exam_occurrence_id,
      :college_id,
      :branch_id,
      :demographic_profile_id
    ])
    |> foreign_key_constraint(:exam_occurrence_id)
    |> foreign_key_constraint(:college_id)
    |> foreign_key_constraint(:branch_id)
    |> foreign_key_constraint(:demographic_profile_id)
    |> validate_number(:opening_rank, greater_than: 0)
    |> validate_number(:closing_rank, greater_than: 0)
  end
end
