defmodule Dbservice.Repo.Migrations.ModifyGroupIdInEnrollmentRecord do
  use Ecto.Migration

  def change do
    alter table(:enrollment_record) do
      remove :group_id
      add :group_id, references(:group_type, on_delete: :nothing)
    end
  end
end
