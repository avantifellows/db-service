defmodule DbserviceWeb.GroupUserJSON do
  def index(%{group_user: group_user}) do
    %{data: for(gu <- group_user, do: data(gu))}
  end

  def show(%{group_user: group_user}) do
    %{data: data(group_user)}
  end

  def batch_result(%{
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
            %{status: :ok, group_user: data(group_user)}

          {:error, changeset} ->
            %{status: :error, errors: changeset}
        end)
    }
  end

  defp data(group_user) do
    %{
      id: group_user.id,
      group_id: group_user.group_id,
      user_id: group_user.user_id
    }
  end
end
