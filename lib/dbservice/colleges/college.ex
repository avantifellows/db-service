defmodule Dbservice.Colleges.College do
  @moduledoc """
  Schema for managing college information.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias Dbservice.Repo

  @required_fields [
    :college_id,
    :institute
  ]

  @optional_fields [
    :state,
    :place,
    :dist_code,
    :co_ed,
    :college_type,
    :year_established,
    :affiliated_to,
    :tuition_fee,
    :af_hierarchy,
    :college_ranking,
    :management_type,
    :expected_salary,
    :salary_tier,
    :qualifying_exam,
    :top_200_nirf
  ]

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id
  schema "colleges" do
    field :college_id, :string
    field :institute, :string
    field :state, :string
    field :place, :string
    field :dist_code, :string
    field :co_ed, :boolean, default: false
    field :college_type, :string
    field :year_established, :integer
    field :affiliated_to, :string
    field :tuition_fee, :decimal
    field :af_hierarchy, :string
    field :college_ranking, :integer
    field :management_type, :string
    field :expected_salary, :decimal
    field :salary_tier, :string
    field :qualifying_exam, :string
    field :top_200_nirf, :boolean, default: false

    timestamps()
  end

  @doc """
  Creates a changeset for college with validation.
  """
  def changeset(college, attrs) do
    college
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:college_id, name: :colleges_college_id_index)
    |> validate_length(:college_id, min: 3, max: 50)
    |> validate_length(:institute, min: 3, max: 255)
    |> validate_number(:year_established,
      greater_than: 1800,
      less_than: Date.utc_today().year + 1
    )
    |> validate_number(:tuition_fee, greater_than_or_equal_to: 0)
    |> validate_number(:expected_salary, greater_than_or_equal_to: 0)
  end

  @doc """
  Gets a single college by ID.
  Returns nil if the college doesn't exist.
  """
  def get_college(id), do: Repo.get(__MODULE__, id)

  @doc """
  Creates a new college.
  """
  def create_college(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a college.
  """
  def update_college(%__MODULE__{} = college, attrs) do
    college
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Lists all colleges with pagination.
  """
  def list_colleges(params) do
    from(c in __MODULE__, order_by: [asc: c.id])
    |> Repo.paginate(params)
  end
end
