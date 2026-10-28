defmodule Dbservice.VisitConcerns.Extraction do
  @moduledoc """
  Pulls the free text out of a School Visit's actions and fingerprints it.

  Pure: takes the Visit's non-deleted actions as `%{id, action_type, data}` and
  never touches the Repo. The fingerprint is opaque to callers; only db-service
  computes or compares it.

  Labels come from stable keys and positions plus class context, never from a
  teacher's or a Student's name:

    * every `classroom_observation` item is prefixed with the observed class,
      `"Grade 11 Physics class observation: <key>"`, or just the grade or the
      subject when only one is valid, and has no prefix when neither is;
    * an `individual_af_teacher_interaction` teacher is `"Teacher <n> (<Subject>)"`
      when the caller's `teacher_subjects` map has a subject for its `id`, else
      `"Teacher <n>"`.

  Labels are part of the fingerprint, so changing how they are built (or a
  teacher's subject changing in the CMS) re-summarises the Visits it touches.
  """

  @question_types ~w(af_team_interaction principal_interaction group_student_discussion school_staff_interaction)

  # Longest subject kept in a label; subject names are free text from the CMS.
  @max_subject_length 40

  @doc """
  The Visit's ordered free-text items, `[%{action_type, label, text}]`.

  `teacher_subjects` maps an `individual_af_teacher_interaction` teacher `id`
  (an LMS `user_permission` id) to that teacher's subject, already passed
  through `subject_text/1`; ids it lacks get no subject.
  """
  def items(actions, teacher_subjects \\ %{}) do
    actions
    |> Enum.sort_by(& &1.id)
    |> Enum.flat_map(&action_items(&1, teacher_subjects))
  end

  @doc """
  The distinct `bigint`-sized positive integer teacher `id`s across the actions'
  `individual_af_teacher_interaction` teachers: the ids `items/2` looks up in
  `teacher_subjects`.
  """
  def teacher_ids(actions) do
    for %{action_type: "individual_af_teacher_interaction", data: %{"teachers" => teachers}} <-
          actions,
        is_list(teachers),
        %{"id" => id} <- teachers,
        id?(id),
        uniq: true,
        do: id
  end

  @doc """
  A subject name made safe for a label: trimmed, inner whitespace runs collapsed
  to one space and capped at #{@max_subject_length} characters. Nil for a blank
  or non-string value.
  """
  def subject_text(value) when is_binary(value) do
    value
    |> String.split()
    |> Enum.join(" ")
    |> String.slice(0, @max_subject_length)
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  def subject_text(_value), do: nil

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
  defp action_items(%{action_type: type, data: %{} = data}, teacher_subjects) do
    prefix = label_prefix(type, data)

    (sources(type, data, teacher_subjects) ++
       [{"additional_notes", Map.get(data, "additional_notes")}])
    |> Enum.flat_map(fn {label, value} -> item(type, prefix <> label, value) end)
  end

  defp action_items(_action, _teacher_subjects), do: []

  # Every item of a classroom observation names the observed class; never the
  # teacher (`teacher_name` is not read).
  defp label_prefix("classroom_observation", data) do
    [grade_text(Map.get(data, "grade")), subject_text(Map.get(data, "subject_name"))]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> ""
      parts -> Enum.join(parts, " ") <> " class observation: "
    end
  end

  defp label_prefix(_type, _data), do: ""

  # "Grade <n>" for an integer, or a string of only digits, from 1 to 99.
  defp grade_text(grade) when is_integer(grade) and grade >= 1 and grade <= 99,
    do: "Grade #{grade}"

  defp grade_text(grade) when is_binary(grade) do
    if grade =~ ~r/\A[0-9]{1,2}\z/, do: grade_text(String.to_integer(grade))
  end

  defp grade_text(_grade), do: nil

  # Fits a Postgres `bigint` key, so the caller's lookup query cannot overflow.
  defp id?(id), do: is_integer(id) and id >= 1 and id <= 9_223_372_036_854_775_807

  defp sources("classroom_observation", data, _teacher_subjects) do
    keyed_remarks(data, "params", "remarks") ++
      [
        {"observer_summary_strengths", Map.get(data, "observer_summary_strengths")},
        {"observer_summary_improvements", Map.get(data, "observer_summary_improvements")}
      ]
  end

  defp sources(type, data, _teacher_subjects) when type in @question_types,
    do: keyed_remarks(data, "questions", "remark")

  # The subject comes from the caller's lookup by `id`; `name` is never read.
  defp sources("individual_af_teacher_interaction", data, teacher_subjects) do
    positioned_remarks(data, "teachers", fn position, teacher ->
      case Map.get(teacher_subjects, Map.get(teacher, "id")) do
        subject when is_binary(subject) -> "Teacher #{position} (#{subject})"
        _ -> "Teacher #{position}"
      end
    end)
  end

  defp sources("individual_student_discussion", data, _teacher_subjects) do
    positioned_remarks(data, "entries", fn
      position, %{"grade" => grade} when is_integer(grade) ->
        "Student entry #{position} (grade #{grade})"

      position, _entry ->
        "Student entry #{position}"
    end)
  end

  defp sources(_type, _data, _teacher_subjects), do: []

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
