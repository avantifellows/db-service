defmodule Dbservice.VisitConcerns.Extraction do
  @moduledoc """
  Pulls the free text out of a School Visit's actions and fingerprints it.

  Pure: takes the Visit's non-deleted actions as `%{id, action_type, data}` and
  never touches the Repo. Labels come from stable keys only, never from names.
  The fingerprint is opaque to callers; only db-service computes or compares it.
  """

  @question_types ~w(af_team_interaction principal_interaction group_student_discussion school_staff_interaction)

  @doc "The Visit's ordered free-text items, `[%{action_type, label, text}]`."
  def items(actions) do
    actions
    |> Enum.sort_by(& &1.id)
    |> Enum.flat_map(&action_items/1)
  end

  @doc """
  Lowercase hex SHA-256 of the compact JSON array of `[action_type, label, text]`
  arrays. Changing this form re-summarises every Visit.
  """
  def fingerprint(items) do
    items
    |> Enum.map(&[&1.action_type, &1.label, &1.text])
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # Every type, including unknown ones, ends with its `additional_notes`.
  defp action_items(%{action_type: type, data: %{} = data}) do
    (sources(type, data) ++ [{"additional_notes", Map.get(data, "additional_notes")}])
    |> Enum.flat_map(fn {label, value} -> item(type, label, value) end)
  end

  defp action_items(_action), do: []

  defp sources("classroom_observation", data) do
    keyed_remarks(data, "params", "remarks") ++
      [
        {"observer_summary_strengths", Map.get(data, "observer_summary_strengths")},
        {"observer_summary_improvements", Map.get(data, "observer_summary_improvements")}
      ]
  end

  defp sources(type, data) when type in @question_types,
    do: keyed_remarks(data, "questions", "remark")

  defp sources("individual_af_teacher_interaction", data) do
    positioned_remarks(data, "teachers", fn position, _teacher -> "Teacher #{position}" end)
  end

  defp sources("individual_student_discussion", data) do
    positioned_remarks(data, "entries", fn
      position, %{"grade" => grade} when is_integer(grade) ->
        "Student entry #{position} (grade #{grade})"

      position, _entry ->
        "Student entry #{position}"
    end)
  end

  defp sources(_type, _data), do: []

  # `{"<prefix>: <key>", remark}` for each map element of the `data[field]` list.
  # Positions count the raw stored list, so a skipped element still uses one up.
  defp positioned_remarks(data, field, prefix) do
    case Map.get(data, field) do
      elements when is_list(elements) ->
        elements
        |> Enum.with_index(1)
        |> Enum.flat_map(fn
          {%{} = element, position} ->
            label = prefix.(position, element)

            element
            |> keyed_remarks("questions", "remark")
            |> Enum.map(fn {key, remark} -> {"#{label}: #{key}", remark} end)

          _ ->
            []
        end)

      _ ->
        []
    end
  end

  # `{key, remark}` for each map element of `data[field]`, keys in byte order.
  defp keyed_remarks(data, field, remark_key) do
    case Map.get(data, field) do
      %{} = entries ->
        entries
        |> Enum.sort_by(fn {key, _} -> key end)
        |> Enum.flat_map(fn
          {key, %{} = entry} -> [{key, Map.get(entry, remark_key)}]
          _ -> []
        end)

      _ ->
        []
    end
  end

  defp item(type, label, value) when is_binary(value) do
    case String.trim(value) do
      "" -> []
      text -> [%{action_type: type, label: label, text: text}]
    end
  end

  defp item(_type, _label, _value), do: []
end
