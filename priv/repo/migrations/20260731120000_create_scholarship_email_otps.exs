defmodule Dbservice.Repo.Migrations.CreateScholarshipEmailOtps do
  use Ecto.Migration

  # Email-OTP verification for the scholarship application flow (Task 1). A
  # dedicated store, deliberately isolated from the phone OTP table
  # (scholarship_otps) since its identifier is an email, plus a verified flag on
  # the application that the submit gate evaluates. Owned by the scholarship app
  # at runtime (read/write via `pg`), authored here per team convention.
  def change do
    create table(:scholarship_email_otps) do
      add :email, :string, null: false
      add :otp_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, null: false, default: 0
      add :consumed_at, :utc_datetime

      timestamps()
    end

    create index(:scholarship_email_otps, [:email])
    create index(:scholarship_email_otps, [:expires_at])

    # The verified-email flag lives as a typed column (the submit gate evaluates
    # it — ADR 0003), defaulting false so existing rows read as unverified.
    alter table(:scholarship_applications) do
      add :email_verified, :boolean, null: false, default: false
    end
  end
end
