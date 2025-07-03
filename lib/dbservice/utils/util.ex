defmodule Dbservice.Utils.Util do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Dbservice.Repo
  alias Dbservice.Groups
  alias Dbservice.GroupUsers
  alias Dbservice.Users

  @valid_categories ~w(Gen OBC SC ST Gen-EWS PWD-SC PWD-Gen PWD-OBC PWD-EWS PWD-ST)
  @valid_genders ~w(Male Female Others)
  @valid_streams ~w(engineering medical pcmb pcm pcb foundation)

  def invalidate_future_date(changeset, date_field_atom) do
    utc_now = DateTime.utc_now()
    ist_now = DateTime.add(utc_now, 5 * 60 * 60 + 30 * 60, :second)
    date_to_validate = get_field(changeset, date_field_atom)

    date_to_validate =
      case date_to_validate do
        %Date{} ->
          DateTime.from_naive!(NaiveDateTime.new!(date_to_validate, ~T[00:00:00]), "Etc/UTC")

        %DateTime{} ->
          date_to_validate

        _ ->
          raise "Unsupported date format"
      end

    if DateTime.compare(date_to_validate, ist_now) == :gt do
      add_error(changeset, date_field_atom, "cannot be later than today")
    else
      changeset
    end
  end

  def validate_date_range(changeset, start_field_atom, end_field_atom) do
    if start_field_atom == :start_date and end_field_atom == :end_date do
      validate_start_end_date(
        changeset,
        get_field(changeset, :start_date),
        get_field(changeset, :end_date)
      )
    else
      validate_start_end_datetime(
        changeset,
        get_field(changeset, :start_time),
        get_field(changeset, :end_time)
      )
    end
  end

  def validate_start_end_datetime(changeset, start_time, end_time) do
    if start_time && end_time && DateTime.compare(start_time, end_time) == :gt do
      add_error(changeset, start_time, "cannot be later than end time")
    else
      changeset
    end
  end

  def validate_start_end_date(changeset, start_date, end_date) do
    if start_date && end_date && Date.compare(start_date, end_date) == :gt do
      add_error(changeset, start_date, "cannot be later than end date")
    else
      changeset
    end
  end

  def build_conditions(params) when is_map(params) do
    Enum.reduce(params, dynamic(true), fn {key, value}, dynamic ->
      if is_nil(value) do
        dynamic([q], is_nil(field(q, ^key)) and ^dynamic)
      else
        dynamic([q], field(q, ^key) == ^value and ^dynamic)
      end
    end)
  end

  def update_users_for_group(group_id, type) do
    # Find the group with type and the given group_id as child_id
    group = Groups.get_group_by_child_id_and_type(group_id, type)

    # Fetch all users associated with this group
    group_users = GroupUsers.get_group_user_by_group_id(group.id)

    # Update the `updated_at` timestamp for all users
    Enum.each(group_users, fn group_user ->
      user = Users.get_user!(group_user.user_id)

      user_changeset =
        Ecto.Changeset.change(user,
          updated_at:
            DateTime.utc_now()
            |> DateTime.add(5 * 60 * 60 + 30 * 60, :second)
            |> DateTime.to_naive()
            |> NaiveDateTime.truncate(:second)
        )

      Repo.update(user_changeset)
    end)

    {:ok, :updated}
  end

  @doc """
  Returns list of valid categories. This can be used in portal to populate categories in dropdown menus
  """
  def valid_categories, do: @valid_categories

  @doc """
  Returns list of valid genders. This can be used in portal to populate genders in dropdown menus
  """
  def valid_genders, do: @valid_genders

  @doc """
  Returns list of valid streams. This can be used in portal to populate streams in dropdown menus
  """
  def valid_streams, do: @valid_streams

  @doc """
  Validates and normalizes category in a changeset.
  Raises an error if the category is invalid.
  """
  def validate_category(changeset, field) do
    validate_field(changeset, field, :category, @valid_categories)
  end

  @doc """
  Validates and normalizes gender in a changeset.
  Raises an error if the gender is invalid.
  """
  def validate_gender(changeset, field) do
    validate_field(changeset, field, :gender, @valid_genders)
  end

  @doc """
  Validates and normalizes stream in a changeset.
  Raises an error if the stream is invalid.
  """
  def validate_stream(changeset, field) do
    validate_field(changeset, field, :stream, @valid_streams)
  end

  # Generic field validator
  defp validate_field(changeset, field, field_type, valid_values) do
    case get_change(changeset, field) do
      nil ->
        changeset

      value ->
        case normalize_value(value, field_type, valid_values) do
          {:ok, normalized} ->
            put_change(changeset, field, normalized)

          {:error, message} ->
            raise ArgumentError, message
        end
    end
  end

  # Generic value normalizer
  defp normalize_value(value, field_type, valid_values) when is_binary(value) do
    normalized =
      valid_values
      |> Enum.find(fn valid ->
        String.upcase(valid) == String.upcase(value)
      end)

    case normalized do
      nil ->
        {:error,
         "Invalid #{field_type}: #{value}. Valid values are: #{Enum.join(valid_values, ", ")}"}

      value ->
        {:ok, value}
    end
  end

  defp normalize_value(nil, _field_type, _valid_values), do: {:ok, nil}

  defp normalize_value(invalid, field_type, _valid_values),
    do: {:error, "#{field_type} must be a string, got: #{inspect(invalid)}"}

  @doc """
  Filters a JSONB `name` field by `lang_code`. If `lang_code` is `"all"`, returns all.
  Defaults to `"en"` if `lang_code` is missing.
  """
  def filter_by_lang(query, params) do
    case Map.get(params, "lang_code", "en") do
      "all" ->
        # No filtering, return all languages
        query

      lang_code ->
        from(u in query,
          where:
            fragment(
              "EXISTS (SELECT 1 FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'lang_code' = ?)",
              u.name,
              ^lang_code
            ),
          select_merge: %{
            name:
              fragment(
                "COALESCE((SELECT JSONB_AGG(obj) FROM JSONB_ARRAY_ELEMENTS(?) obj WHERE obj->>'lang_code' = ?), '[]'::JSONB)",
                u.name,
                ^lang_code
              )
          }
        )
    end
  end
end
