defmodule Dbservice.Repo.Migrations.RemoveAcademicYearFromAuthGroupEr do
  use Ecto.Migration

  def up do
    execute """
    UPDATE enrollment_record
    SET academic_year = NULL
    WHERE group_type = 'auth_group'
    """
  end

  def down do
    execute "-- No reliable way to restore previous academic_year values"
  end
end
