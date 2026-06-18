defmodule Dbservice.Services.GurukulConfigService do
  @moduledoc """
  Resolves Gurukul UI configuration by merging config along the fallback chain:

      defaultgroup  <-  auth_group  <-  program  <-  batch    (later layers win)

  Each layer namespaces its Gurukul config under the `"gurukul_config"` key so
  the same column can hold config for other modules (CMS, LMS, etc.) without
  collision:
    * defaultgroup: the `DefaultGroup` auth_group's `locale_data["gurukul_config"]`
    * auth_group:   the user's current auth_group's `locale_data["gurukul_config"]` (e.g. EnableSchools)
    * program:      `program.config["gurukul_config"]`
    * batch:        `batch.metadata["gurukul_config"]`

  The `auth_group` layer only applies when resolving for a user: a user enrolled
  in an auth group (but no batch/program) picks up that group's config instead of
  falling straight through to defaultgroup. `resolve_for_batch/1` and
  `resolve_for_program/1` have no user context, so they skip this layer.

  When a user belongs to multiple current batches (or programs), the oldest
  enrollment (earliest `start_date`) wins, per the agreed resolution rule:
  the older batch is most likely the student's primary one.

  Each resolve function returns `{config, resolved_from}` where `resolved_from`
  records which layer the config was resolved from, for observability.
  """

  import Ecto.Query, warn: false

  alias Dbservice.Batches.Batch
  alias Dbservice.EnrollmentRecords.EnrollmentRecord
  alias Dbservice.Groups.AuthGroup
  alias Dbservice.Programs.Program
  alias Dbservice.Repo

  @default_group_name "DefaultGroup"
  @config_key "gurukul_config"

  @doc """
  Resolves the merged Gurukul config for a user via their oldest current
  batch (falling back to their oldest current program, then defaultgroup).
  """
  def resolve_for_user(user_id) do
    {base, auth_group_id} = user_base_config(user_id)

    case oldest_current_enrollment(user_id, "batch") do
      %EnrollmentRecord{group_id: batch_id} ->
        resolve_from_batch(batch_id, base, auth_group_id)

      nil ->
        case oldest_current_enrollment(user_id, "program") do
          %EnrollmentRecord{group_id: program_id} ->
            resolve_from_program(program_id, base, auth_group_id)

          nil ->
            {base, base_resolved_from(auth_group_id)}
        end
    end
  end

  @doc """
  Resolves config for a batch directly: batch <- program <- defaultgroup.

  No user context, so the auth_group layer is skipped.
  """
  def resolve_for_batch(batch_id), do: resolve_from_batch(batch_id, default_config(), nil)

  @doc """
  Resolves config for a program directly: program <- defaultgroup.

  No user context, so the auth_group layer is skipped.
  """
  def resolve_for_program(program_id), do: resolve_from_program(program_id, default_config(), nil)

  # Builds the base config for a user: defaultgroup overlaid with the user's
  # current auth_group config (e.g. EnableSchools). Returns {config, auth_group_id}
  # where auth_group_id is nil when the user has no current auth_group enrollment.
  defp user_base_config(user_id) do
    base = default_config()

    case oldest_current_enrollment(user_id, "auth_group") do
      %EnrollmentRecord{group_id: auth_group_id} ->
        case Repo.get(AuthGroup, auth_group_id) do
          %AuthGroup{locale_data: locale_data} ->
            {Map.merge(base, gurukul_section(locale_data)), auth_group_id}

          _ ->
            {base, nil}
        end

      nil ->
        {base, nil}
    end
  end

  defp resolve_from_batch(batch_id, base, auth_group_id) do
    case Repo.get(Batch, batch_id) do
      nil ->
        {base, base_resolved_from(auth_group_id)}

      %Batch{} = batch ->
        program_config =
          case batch.program_id && Repo.get(Program, batch.program_id) do
            %Program{config: config} -> gurukul_section(config)
            _ -> %{}
          end

        batch_config = gurukul_section(batch.metadata)

        merged = base |> Map.merge(program_config) |> Map.merge(batch_config)

        {merged,
         %{
           source: "batch",
           batch_id: batch.id,
           program_id: batch.program_id,
           auth_group_id: auth_group_id
         }}
    end
  end

  defp resolve_from_program(program_id, base, auth_group_id) do
    case Repo.get(Program, program_id) do
      nil ->
        {base, base_resolved_from(auth_group_id)}

      %Program{} = program ->
        {Map.merge(base, gurukul_section(program.config)),
         %{source: "program", batch_id: nil, program_id: program.id, auth_group_id: auth_group_id}}
    end
  end

  # The resolved_from for the base layer: reports "auth_group" when the user's
  # auth_group config contributed, otherwise "defaultgroup".
  defp base_resolved_from(nil),
    do: %{source: "defaultgroup", batch_id: nil, program_id: nil, auth_group_id: nil}

  defp base_resolved_from(auth_group_id),
    do: %{source: "auth_group", batch_id: nil, program_id: nil, auth_group_id: auth_group_id}

  defp oldest_current_enrollment(user_id, group_type) do
    from(e in EnrollmentRecord,
      where: e.user_id == ^user_id and e.group_type == ^group_type and e.is_current == true,
      order_by: [asc_nulls_last: e.start_date, asc: e.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp default_config do
    case Repo.get_by(AuthGroup, name: @default_group_name) do
      %AuthGroup{locale_data: locale_data} -> gurukul_section(locale_data)
      _ -> %{}
    end
  end

  # Reads the namespaced Gurukul config out of a column map (auth_group.locale_data,
  # program.config, batch.metadata), leaving other modules' keys alone.
  defp gurukul_section(map) when is_map(map), do: Map.get(map, @config_key, %{})
  defp gurukul_section(_), do: %{}
end
