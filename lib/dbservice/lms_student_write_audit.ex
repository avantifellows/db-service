defmodule Dbservice.LmsStudentWriteAudit do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "lms_student_write_audits" do
    field :action, :string
    field :actor_user_id, :integer
    field :actor_email, :string
    field :actor_login_type, :string
    field :actor_role, :string
    field :school_code, :string
    field :school_udise_code, :string
    field :program_id, :integer
    field :upload_id, :string
    field :upload_filename, :string
    field :row_number, :integer
    field :row_counts, :map, default: %{}
    field :affected_identifiers, :map, default: %{}
    field :created_values, :map, default: %{}
    field :changed_values, :map, default: %{}

    timestamps()
  end

  def changeset(audit, attrs) do
    audit
    |> cast(attrs, [
      :action,
      :actor_user_id,
      :actor_email,
      :actor_login_type,
      :actor_role,
      :school_code,
      :school_udise_code,
      :program_id,
      :upload_id,
      :upload_filename,
      :row_number,
      :row_counts,
      :affected_identifiers,
      :created_values,
      :changed_values
    ])
    |> validate_required([
      :action,
      :actor_email,
      :actor_login_type,
      :actor_role,
      :row_counts,
      :affected_identifiers,
      :created_values,
      :changed_values
    ])
  end
end
