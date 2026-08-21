defmodule Dbservice.Repo.Migrations.AddScholarshipReviewersAlekhyaAgny do
  use Ecto.Migration

  @reviewers ["alekhya@avantifellows.org", "agny@avantifellows.org"]

  def up do
    for email <- @reviewers do
      name = email |> String.split("@") |> hd()

      repo().query!(
        """
        INSERT INTO scholarship_reviewers (email, name, role, is_active, inserted_at, updated_at)
        VALUES ($1, $2, 'reviewer', true, NOW(), NOW())
        ON CONFLICT (email) DO UPDATE SET is_active = true, updated_at = NOW()
        """,
        [email, name]
      )
    end
  end

  def down do
    repo().query!("DELETE FROM scholarship_reviewers WHERE email = ANY($1)", [@reviewers])
  end
end
