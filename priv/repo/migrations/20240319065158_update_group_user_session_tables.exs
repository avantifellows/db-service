defmodule Dbservice.Repo.Migrations.UpdateGroupUserSessionTables do
  use Ecto.Migration

  def change do
    rename table("group_session"), :group_type_id, to: :group_id
    rename table("group_user"), :group_type_id, to: :group_id
    
    alter table("group_user") do
      remove :program_manager_id
      remove :program_date_of_joining
      remove :program_student_language

      modify :user_id, :integer, null: false
    end
  end
end
