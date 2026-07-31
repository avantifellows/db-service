defmodule Dbservice.Utils.AcademicYearTest do
  use ExUnit.Case, async: true

  alias Dbservice.Utils.AcademicYear

  describe "current_academic_year/1" do
    test "a date before the April rollover belongs to the prior academic year" do
      assert AcademicYear.current_academic_year(~D[2026-03-31]) == "2025-2026"
      assert AcademicYear.current_academic_year(~D[2026-01-10]) == "2025-2026"
    end

    test "April 1st is the first day of the new academic year" do
      assert AcademicYear.current_academic_year(~D[2026-04-01]) == "2026-2027"
    end

    test "a date after the rollover belongs to the current academic year" do
      assert AcademicYear.current_academic_year(~D[2026-07-29]) == "2026-2027"
      assert AcademicYear.current_academic_year(~D[2026-12-15]) == "2026-2027"
    end

    test "always returns canonical YYYY-YYYY form" do
      assert AcademicYear.current_academic_year(~D[2030-05-01]) == "2030-2031"
      assert AcademicYear.current_academic_year(~D[2030-02-01]) == "2029-2030"
    end
  end

  describe "current_academic_year/0" do
    test "returns a canonical YYYY-YYYY string" do
      assert AcademicYear.current_academic_year() =~ ~r/\A\d{4}-\d{4}\z/
    end
  end
end
