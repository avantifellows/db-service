defmodule DbserviceWeb.BranchJSON do
  def index(%{branches: branches}) do
    for(b <- branches, do: render(b))
  end

  def show(%{branch: branch}) do
    render(branch)
  end

  # Already-shaped %{id, branch_id, name} maps from Branches.list_branch_names/1
  def names(%{branch_names: branch_names}) do
    branch_names
  end

  def render(branch) do
    %{
      id: branch.id,
      branch_id: branch.branch_id,
      parent_branch_id: branch.parent_branch_id,
      name: branch.name,
      duration: branch.duration
    }
  end
end
