defmodule Dbservice.BlendedLearning do
  @moduledoc """
  Blended Learning mentor-mentee mappings.

  Blended Learning has no teachers; mentorship is done by ops people. A mapping
  records which mentor owns a student for an academic year, and mappings are
  never deleted: a reassignment ends the running mapping and starts a new one,
  so the history of who mentored whom survives.

  Queries are schemaless, matching `Dbservice.HolisticMentorship`, since the
  mapping tables have no Ecto schema.
  """

  import Ecto.Query

  alias Dbservice.Repo

  @mapping_table "blended_learning_mentor_mentee_mappings"
  @data_import_source "data_import"
  @reassignment_end_reason "mentor_reassigned"

  @doc """
  Assigns a mentor to a student for an academic year.

  Returns `{:ok, :assigned}` for a fresh mapping, `{:ok, :reassigned}` when a
  different mentor was running and has been ended, and `{:ok, :unchanged}` when
  the same mentor is already running (so re-running the same sheet is a no-op).

  The running mapping is ended at the new mapping's `started_at`, leaving no gap
  or overlap between the two periods.
  """
  def assign_mentor(attrs) do
    Repo.transaction(fn -> do_assign_mentor(attrs) end)
  rescue
    error in Postgrex.Error -> {:error, database_error_message(error)}
  end

  defp do_assign_mentor(attrs) do
    running = active_mapping(attrs.student_id, attrs.academic_year)

    cond do
      is_nil(running) ->
        insert_mapping(attrs)
        :assigned

      running.mentor_user_id == attrs.mentor_user_id ->
        :unchanged

      true ->
        reassign(running, attrs)
    end
  end

  defp reassign(running, attrs) do
    if NaiveDateTime.compare(attrs.started_at, running.started_at) == :lt do
      Repo.rollback(
        "started_at #{NaiveDateTime.to_string(attrs.started_at)} is before the running mapping's " <>
          "started_at #{NaiveDateTime.to_string(running.started_at)}; a mentorship cannot start " <>
          "before the one it replaces"
      )
    else
      end_mapping(running, attrs)
      insert_mapping(attrs)
      :reassigned
    end
  end

  # Locked so two concurrent imports cannot both end up inserting for the same
  # student and academic year; a row that never existed is still guarded by
  # blm_mappings_active_student_year_unique.
  defp active_mapping(student_id, academic_year) do
    from(mapping in @mapping_table,
      where:
        mapping.student_id == ^student_id and mapping.academic_year == ^academic_year and
          is_nil(mapping.ended_at),
      select: %{
        id: mapping.id,
        mentor_user_id: mapping.mentor_user_id,
        started_at: mapping.started_at
      },
      lock: "FOR UPDATE"
    )
    |> Repo.one()
  end

  defp end_mapping(running, attrs) do
    from(mapping in @mapping_table, where: mapping.id == ^running.id)
    |> Repo.update_all(
      set: [
        ended_at: attrs.started_at,
        ended_by_user_id: attrs.assigned_by_user_id,
        ended_by_email: attrs.assigned_by_email,
        end_source: @data_import_source,
        end_reason: @reassignment_end_reason,
        end_audit_reason: attrs.assignment_audit_reason,
        updated_at: now()
      ]
    )
  end

  defp insert_mapping(attrs) do
    now = now()

    Repo.insert_all(@mapping_table, [
      %{
        student_id: attrs.student_id,
        mentor_user_id: attrs.mentor_user_id,
        # Blended is not attached to a physical school; the column stays blank.
        school_id: nil,
        program_id: attrs.program_id,
        academic_year: attrs.academic_year,
        started_at: attrs.started_at,
        assigned_by_user_id: attrs.assigned_by_user_id,
        assigned_by_email: attrs.assigned_by_email,
        assignment_source: @data_import_source,
        assignment_audit_reason: attrs.assignment_audit_reason,
        inserted_at: now,
        updated_at: now
      }
    ])
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

  defp database_error_message(%Postgrex.Error{postgres: %{constraint: constraint}})
       when is_binary(constraint) do
    case constraint do
      "blm_mappings_active_student_year_unique" ->
        "Student already has a running mentor mapping for this academic year"

      other ->
        "Mapping rejected by the database (#{other})"
    end
  end

  defp database_error_message(error), do: Exception.message(error)
end
