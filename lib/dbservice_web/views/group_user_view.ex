defmodule DbserviceWeb.GroupUserView do
  use DbserviceWeb, :view
  alias DbserviceWeb.GroupUserView

  def render("index.json", %{group_user: group_user}) do
    render_many(group_user, GroupUserView, "group_user.json")
  end

  def render("show.json", %{group_user: group_user}) do
    render_one(group_user, GroupUserView, "group_user.json")
  end

  def render("group_user.json", %{group_user: group_user}) do
    %{
      id: group_user.id,
      group_id: group_user.group_id,
      user_id: group_user.user_id
    }
  end

  def render("batch_result.json", %{
        message: message,
        successful: successful,
        failed: failed,
        results: results
      }) do
    %{
      message: message,
      successful: successful,
      failed: failed,
      results:
        Enum.map(results, fn
          {:ok, group_user} ->
            %{status: :ok, group_user: render_one(group_user, GroupUserView, "group_user.json")}

          {:error, changeset} ->
            %{status: :error, errors: changeset}
        end)
    }
  end
end
