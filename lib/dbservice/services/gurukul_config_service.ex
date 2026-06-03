defmodule Dbservice.Services.GurukulConfigService do
  @moduledoc """
  Resolves Gurukul UI configuration by merging config along the fallback chain:

      defaultgroup  <-  program  <-  batch       (later layers win)

  Storage locations for each layer:
    * defaultgroup: the `auth_group` named "defaultgroup", under
      `input_schema["gurukul_config"]`
    * program:      `program.config`
    * batch:        `batch.metadata["gurukul_config"]`

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

  @default_group_name "defaultgroup"
  @config_key "gurukul_config"

  @doc """
  Resolves the merged Gurukul config for a user via their oldest current
  batch (falling back to their oldest current program, then defaultgroup).
  """
  def resolve_for_user(user_id) do
    base = default_config()

    case oldest_current_enrollment(user_id, "batch") do
      %EnrollmentRecord{group_id: batch_id} ->
        resolve_from_batch(batch_id, base)

      nil ->
        case oldest_current_enrollment(user_id, "program") do
          %EnrollmentRecord{group_id: program_id} -> resolve_from_program(program_id, base)
          nil -> {base, %{source: "defaultgroup", batch_id: nil, program_id: nil}}
        end
    end
  end

  @doc """
  Resolves config for a batch directly: batch <- program <- defaultgroup.
  """
  def resolve_for_batch(batch_id), do: resolve_from_batch(batch_id, default_config())

  @doc """
  Resolves config for a program directly: program <- defaultgroup.
  """
  def resolve_for_program(program_id), do: resolve_from_program(program_id, default_config())

  defp resolve_from_batch(batch_id, base) do
    case Repo.get(Batch, batch_id) do
      nil ->
        {base, %{source: "defaultgroup", batch_id: nil, program_id: nil}}

      %Batch{} = batch ->
        program_config =
          case batch.program_id && Repo.get(Program, batch.program_id) do
            %Program{config: config} -> config || %{}
            _ -> %{}
          end

        batch_config = Map.get(batch.metadata || %{}, @config_key, %{})

        merged = base |> Map.merge(program_config) |> Map.merge(batch_config)
        {merged, %{source: "batch", batch_id: batch.id, program_id: batch.program_id}}
    end
  end

  defp resolve_from_program(program_id, base) do
    case Repo.get(Program, program_id) do
      nil ->
        {base, %{source: "defaultgroup", batch_id: nil, program_id: nil}}

      %Program{} = program ->
        {Map.merge(base, program.config || %{}),
         %{source: "program", batch_id: nil, program_id: program.id}}
    end
  end

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
      %AuthGroup{input_schema: input_schema} when is_map(input_schema) ->
        Map.get(input_schema, @config_key, %{})

      _ ->
        %{}
    end
  end
end
