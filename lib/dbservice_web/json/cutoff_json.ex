defmodule DbserviceWeb.CutoffJSON do
  def index(%{cutoffs: cutoffs}) do
    for(c <- cutoffs, do: render(c))
  end

  def show(%{cutoff: cutoff}) do
    render(cutoff)
  end

  def render(cutoff) do
    %{
      id: cutoff.id,
      cutoff_year: cutoff.cutoff_year,
      exam_occurrence_id: cutoff.exam_occurrence_id,
      college_id: cutoff.college_id,
      degree: cutoff.degree,
      branch_id: cutoff.branch_id,
      category: cutoff.category,
      state_quota: cutoff.state_quota,
      opening_rank: cutoff.opening_rank,
      closing_rank: cutoff.closing_rank,
      exam_occurrence: render_association(cutoff.exam_occurrence, &DbserviceWeb.ExamOccurrenceJSON.render/1),
      college: render_association(cutoff.college, &DbserviceWeb.CollegeJSON.render/1),
      branch: render_association(cutoff.branch, &DbserviceWeb.BranchJSON.render/1)
    }
  end

  defp render_association(%Ecto.Association.NotLoaded{}, _render_fn), do: nil
  defp render_association(nil, _render_fn), do: nil
  defp render_association(association, render_fn), do: render_fn.(association)
end
