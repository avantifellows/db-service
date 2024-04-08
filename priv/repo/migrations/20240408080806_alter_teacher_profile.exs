defmodule Dbservice.Repo.Migrations.AlterTeacherProfile do
  use Ecto.Migration

  def change do
    alter table(:teacher_profile) do
      remove :uuid
      remove :designation
      remove :subject
    end

    rename table(:teacher_profile), :teacher_id, to: :teacher_fk

    alter table(:teacher_profile) do
      add(:teacher_id, :string)
    end

    drop index(:teacher_profile, [:teacher_id], name: "index_teacher_profile_on_teacher_id")

    create index(:teacher_profile, [:teacher_fk], name: "index_teacher_profile_on_teacher_fk")
  end
end
