defmodule DbserviceWeb.CandidateJSON do
  alias DbserviceWeb.UserJSON
  alias Dbservice.Repo

  def index(%{candidate: candidate}) do
    for(c <- candidate, do: render(c))
  end

  def show(%{candidate: candidate}) do
    render(candidate)
  end

  def render(candidate) do
    candidate = Repo.preload(candidate, [:subject, :user])

    %{
      id: candidate.id,
      degree: candidate.degree,
      college_name: candidate.college_name,
      branch_name: candidate.branch_name,
      latest_cgpa: candidate.latest_cgpa,
      subject_id: candidate.subject_id,
      candidate_id: candidate.candidate_id,
      user_id: candidate.user_id,
      user: if(candidate.user, do: UserJSON.render(candidate.user), else: nil)
    }
  end
end
