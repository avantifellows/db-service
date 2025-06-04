defmodule DbserviceWeb.SchoolBatchJSON do

  def index(%{school_batch: school_batch}) do
    %{data: for(sb <- school_batch, do: data(sb))}
  end

  def show(%{school_batch: school_batch}) do
    %{data: data(school_batch)}
  end

  def data(school_batch) do
    %{
      id: school_batch.id,
      school_id: school_batch.school_id,
      batch_id: school_batch.batch_id
    }
  end
end
