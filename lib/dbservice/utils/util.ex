defmodule Dbservice.Utils.Util do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  def invalidate_future_date(changeset, date_field_atom) do
    today = Date.utc_today()
    date_to_validate = get_field(changeset, date_field_atom)

    if Date.compare(date_to_validate, today) == :gt do
      add_error(changeset, date_field_atom, "cannot be later than today")
    else
      changeset
    end
  end

  def validate_date_time(changeset, start_time_field_atom, end_time_field_atom) do
    start_time = get_field(changeset, start_time_field_atom)
    end_time = get_field(changeset, end_time_field_atom)

    if DateTime.compare(start_time, end_time) == :gt do
      add_error(changeset, start_time_field_atom, "cannot be later than end time")
    else
      changeset
    end
  end
end
