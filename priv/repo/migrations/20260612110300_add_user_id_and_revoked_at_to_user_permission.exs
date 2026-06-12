defmodule Dbservice.Repo.Migrations.AddUserIdAndRevokedAtToUserPermission do
  use Ecto.Migration

  def change do
    alter table(:user_permission) do
      # Explicit person link; the email join is fragile (user.email is
      # nullable and unverified-unique).
      add :user_id, references(:user, on_delete: :nothing)
      # Access revocation (distinct from employment exit) — replaces the
      # current hard-delete flow for offboarding.
      add :revoked_at, :naive_datetime
    end

    create index(:user_permission, [:user_id])
  end
end
