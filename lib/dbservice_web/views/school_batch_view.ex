defmodule DbserviceWeb.SchoolBatchView do
  use DbserviceWeb, :view
  alias DbserviceWeb.SchoolBatchView

  def render("index.json", %{school_batch: school_batch}) do
    render_many(school_batch, SchoolBatchView, "school_batch.json")
  end

  def render("show.json", %{school_batch: school_batch}) do
    render_one(school_batch, SchoolBatchView, "school_batch.json")
  end

  def render("school_batch.json", %{school_batch: school_batch}) do
    %{
      id: school_batch.id,
      school_id: school_batch.school_id,
      batch_id: school_batch.batch_id
    }
  end
end
