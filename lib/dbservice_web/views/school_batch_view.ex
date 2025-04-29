defmodule DbserviceWeb.SchoolBatchView do
  use DbserviceWeb, :view

  def render("index.json", %{school_batch: school_batches}) do
    Enum.map(school_batches, &school_batch_json/1)
  end

  def render("show.json", %{school_batch: school_batch}) do
    school_batch_json(school_batch)
  end

  def render("school_batch.json", %{school_batch: school_batch}) do
    %{
      id: school_batch.id,
      school_id: school_batch.school_id,
      batch_id: school_batch.batch_id
    }
  end

  def school_batch_json(school_batch) do
    render("school_batch.json", %{school_batch: school_batch})
  end
end
