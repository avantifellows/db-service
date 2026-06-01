defmodule Dbservice.AcademicMentorshipMappings do
  @moduledoc """
  The AcademicMentorshipMappings context.
  """

  import Ecto.Query, warn: false
  alias Dbservice.Repo

  alias Dbservice.AcademicMentorshipMappings.AcademicMentorshipMapping

  def get_mapping!(id), do: Repo.get!(AcademicMentorshipMapping, id)

  def get_mapping(id), do: Repo.get(AcademicMentorshipMapping, id)

  def list_active_mappings(mentor_ids, academic_year) do
    query =
      from m in AcademicMentorshipMapping,
        where: is_nil(m.deleted_at),
        order_by: [asc: m.mentor_id, asc: m.id]

    query =
      if mentor_ids != [] do
        from m in query, where: m.mentor_id in ^mentor_ids
      else
        query
      end

    query =
      if academic_year do
        from m in query, where: m.academic_year == ^academic_year
      else
        query
      end

    Repo.all(query)
  end

  def create_mapping(attrs \\ %{}) do
    %AcademicMentorshipMapping{}
    |> AcademicMentorshipMapping.changeset(attrs)
    |> Repo.insert()
  end

  def create_mappings_batch(mappings_attrs) when is_list(mappings_attrs) do
    Repo.transaction(fn ->
      Enum.reduce_while(mappings_attrs, [], fn attrs, acc ->
        case create_mapping(attrs) do
          {:ok, mapping} ->
            {:cont, [mapping | acc]}

          {:error, changeset} ->
            Repo.rollback({:validation_error, changeset, length(acc)})
        end
      end)
      |> Enum.reverse()
    end)
  end

  def soft_delete_mapping(id, updated_by) do
    case get_mapping(id) do
      nil ->
        {:error, :not_found}

      %AcademicMentorshipMapping{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :already_deleted}

      mapping ->
        mapping
        |> AcademicMentorshipMapping.soft_delete_changeset(%{
          deleted_at: DateTime.utc_now() |> DateTime.truncate(:second),
          updated_by: updated_by
        })
        |> Repo.update()
    end
  end

  def reassign_mapping(old_mapping_id, new_mentor_id, updated_by) do
    Repo.transaction(fn ->
      case get_mapping(old_mapping_id) do
        nil ->
          Repo.rollback(:not_found)

        %AcademicMentorshipMapping{deleted_at: deleted_at} when not is_nil(deleted_at) ->
          Repo.rollback(:already_deleted)

        old_mapping ->
          now = DateTime.utc_now() |> DateTime.truncate(:second)

          case old_mapping
               |> AcademicMentorshipMapping.soft_delete_changeset(%{
                 deleted_at: now,
                 updated_by: updated_by
               })
               |> Repo.update() do
            {:ok, _} ->
              new_attrs = %{
                "mentor_id" => new_mentor_id,
                "mentee_id" => old_mapping.mentee_id,
                "academic_year" => old_mapping.academic_year,
                "created_by" => old_mapping.created_by
              }

              case %AcademicMentorshipMapping{}
                   |> AcademicMentorshipMapping.changeset(new_attrs)
                   |> Repo.insert() do
                {:ok, new_mapping} -> new_mapping
                {:error, changeset} -> Repo.rollback({:insert_error, changeset})
              end

            {:error, changeset} ->
              Repo.rollback({:update_error, changeset})
          end
      end
    end)
  end

  def has_any_mappings_for_mentor?(mentor_id) do
    from(m in AcademicMentorshipMapping, where: m.mentor_id == ^mentor_id, limit: 1)
    |> Repo.exists?()
  end
end
