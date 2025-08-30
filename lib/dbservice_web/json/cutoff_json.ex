defmodule DbserviceWeb.CutoffJSON do
  def index(%{cutoffs: cutoffs}) do
    for(c <- cutoffs, do: render(c))
  end

  def show(%{cutoff: cutoff}) do
    render(cutoff)
  end

  def render(cutoff) do
    base_cutoff = %{
      id: cutoff.id,
      cutoff_year: cutoff.cutoff_year,
      exam_occurrence_id: cutoff.exam_occurrence_id,
      college_id: cutoff.college_id,
      degree: cutoff.degree,
      branch_id: cutoff.branch_id,
      category_id: cutoff.category_id,
      state_quota: cutoff.state_quota,
      opening_rank: cutoff.opening_rank,
      closing_rank: cutoff.closing_rank
    }

    # Include associations if they are loaded
    base_cutoff
    |> maybe_include_exam_occurrence(cutoff)
    |> maybe_include_college(cutoff)
    |> maybe_include_branch(cutoff)
  end

  defp maybe_include_exam_occurrence(cutoff_data, cutoff) do
    case Map.get(cutoff, :exam_occurrence) do
      %Ecto.Association.NotLoaded{} ->
        cutoff_data

      nil ->
        cutoff_data

      exam_occurrence ->
        Map.put(
          cutoff_data,
          :exam_occurrence,
          DbserviceWeb.ExamOccurrenceJSON.render(exam_occurrence)
        )
    end
  end

  defp maybe_include_college(cutoff_data, cutoff) do
    case Map.get(cutoff, :college) do
      %Ecto.Association.NotLoaded{} ->
        cutoff_data

      nil ->
        cutoff_data

      college ->
        Map.put(cutoff_data, :college, DbserviceWeb.CollegeJSON.render(college))
    end
  end

  defp maybe_include_branch(cutoff_data, cutoff) do
    case Map.get(cutoff, :branch) do
      %Ecto.Association.NotLoaded{} ->
        cutoff_data

      nil ->
        cutoff_data

      branch ->
        Map.put(cutoff_data, :branch, DbserviceWeb.BranchJSON.render(branch))
    end
  end
end
