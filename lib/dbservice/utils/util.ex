defmodule Dbservice.Utils.Util do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

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
end
