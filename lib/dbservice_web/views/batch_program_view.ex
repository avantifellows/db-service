defmodule DbserviceWeb.BatchProgramView do
  use DbserviceWeb, :view
  alias DbserviceWeb.BatchProgramView

  def render("index.json", %{batch_program: batch_program}) do
    render_many(batch_program, BatchProgramView, "batch_program.json")
  end

  def render("show.json", %{batch_program: batch_program}) do
    render_one(batch_program, BatchProgramView, "batch_program.json")
  end

  def render("batch_program.json", %{batch_program: batch_program}) do
    %{
      id: batch_program.id,
      batch_id: batch_program.batch_id,
      program_id: batch_program.program_id
    }
  end
end
