defmodule DbserviceWeb.BranchJSON do
  def index(%{branches: branches}) do
    for(b <- branches, do: render(b))
  end

  def show(%{branch: branch}) do
    render(branch)
  end

  def render(branch) do
    %{
      id: branch.id,
      branch_id: branch.branch_id,
      parent_branch: branch.parent_branch,
      name: branch.name,
      duration: branch.duration
    }
  end
end
