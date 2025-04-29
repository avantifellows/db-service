defmodule DbserviceWeb.GroupUserView do
  use DbserviceWeb, :view

  def render("index.json", %{group_user: group_user}) do
    Enum.map(group_user, &group_user_json/1)
  end

  def render("show.json", %{group_user: group_user}) do
    group_user_json(group_user)
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
            %{status: :ok, group_user: group_user_json(group_user)}

          {:error, changeset} ->
            %{status: :error, errors: changeset}
        end)
    }
  end

  def group_user_json(group_user) do
    %{
      id: group_user.id,
      group_id: group_user.group_id,
      user_id: group_user.user_id
    }
  end
end
