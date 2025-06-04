defmodule DbserviceWeb.BatchJSON do
  def index(%{batch: batch}) do
    %{data: for(b <- batch, do: data(b))}
  end

  def show(%{batch: batch}) do
    %{data: data(batch)}
  end

  def data(batch) do
    %{
      id: batch.id,
      name: batch.name,
      contact_hours_per_week: batch.contact_hours_per_week,
      batch_id: batch.batch_id,
      parent_id: batch.parent_id,
      start_date: batch.start_date,
      end_date: batch.end_date,
      program_id: batch.program_id,
      auth_group_id: batch.auth_group_id,
      af_medium: batch.af_medium
    }
  end
end
