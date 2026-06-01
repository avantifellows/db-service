defmodule DbserviceWeb.AcademicMentorshipMappingJSON do
  def index(%{mappings: mappings}) do
    %{mappings: for(m <- mappings, do: render(m))}
  end

  def show(%{mapping: mapping}) do
    %{mapping: render(mapping)}
  end

  defp render(mapping) do
    %{
      id: mapping.id,
      mentor_id: mapping.mentor_id,
      mentee_id: mapping.mentee_id,
      academic_year: mapping.academic_year,
      created_by: mapping.created_by,
      updated_by: mapping.updated_by,
      deleted_at: mapping.deleted_at,
      inserted_at: mapping.inserted_at,
      updated_at: mapping.updated_at
    }
  end
end
