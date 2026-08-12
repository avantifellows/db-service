defmodule Dbservice.Utils.AcademicYear do
  @moduledoc """
  Single source of truth for the *current* academic year.

  Academic years are written in canonical `YYYY-YYYY` form (e.g. `"2026-2027"`).
  The current academic year is derived from the calendar rather than taken from
  user input, so current-student import flows can't accidentally stamp a stale
  year onto an enrollment record. (Historical import flows still supply the year
  manually — this module is only used by the current-student flows.)

  The year rolls over in **April**: on/after April the academic year is
  `"{Y}-{Y+1}"`; before April it is `"{Y-1}-{Y}"`.
  """

  # Month (1-12) in which a new academic year begins. Single knob for the
  # rollover boundary; April = 4.
  @rollover_start_month 4

  # IST is UTC+5:30. The rollover boundary and "today" are evaluated in IST so a
  # request just after midnight (or on April 1st) resolves to the Indian date,
  # not the UTC one.
  @ist_offset_seconds 5 * 60 * 60 + 30 * 60

  @doc """
  Returns the current academic year in `YYYY-YYYY` form, based on today's date
  in IST.
  """
  def current_academic_year do
    ist_today =
      DateTime.utc_now()
      |> DateTime.add(@ist_offset_seconds, :second)
      |> DateTime.to_date()

    current_academic_year(ist_today)
  end

  @doc """
  Returns the academic year in `YYYY-YYYY` form for the given `Date`.

  Testable core: `~D[2026-03-31]` -> `"2025-2026"`, `~D[2026-04-01]` ->
  `"2026-2027"`.
  """
  def current_academic_year(%Date{year: year, month: month}) do
    if month >= @rollover_start_month do
      "#{year}-#{year + 1}"
    else
      "#{year - 1}-#{year}"
    end
  end
end
