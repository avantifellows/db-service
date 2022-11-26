defmodule Dbservice.Groups.Group do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Dbservice.Users.User
  alias Dbservice.Sessions.Session

  schema "group" do
    field :name, :string
    field :parent_id, :integer
    field :type, Ecto.Enum, values: [:batch, :group, :cohort, :program]
    field :program_type, :string
    field :program_sub_type, :string
    field :program_mode, :string
    field :program_start_date, :date
    field :program_target_outreach, :integer
    field :program_product_used, :string
    field :program_donor, :string
    field :program_state, :string
    field :batch_contact_hours_per_week, :integer
    field :group_input_schema, :map
    field :group_locale, :string
    field :group_locale_data, :map
    field :auth_type, {:array, :string}

    many_to_many :user, User, join_through: "group_user", on_replace: :delete
    many_to_many :session, Session, join_through: "group_session", on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :parent_id,
      :type,
      :program_type,
      :program_sub_type,
      :program_mode,
      :program_start_date,
      :program_target_outreach,
      :program_product_used,
      :program_donor,
      :program_state,
      :batch_contact_hours_per_week,
      :group_input_schema,
      :group_locale,
      :group_locale_data,
      :auth_type
    ])
    |> validate_required([:name, :type])
  end
end
