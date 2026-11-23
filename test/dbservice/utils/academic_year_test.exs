defmodule Dbservice.Utils.AcademicYearTest do
  use ExUnit.Case, async: true

  alias Dbservice.Utils.AcademicYear

  describe "parse/1" do
    test "splits a YYYY-YYYY value into its two years" do
      assert AcademicYear.parse("2026-2027") == {:ok, {2026, 2027}}
      assert AcademicYear.parse("2025-2027") == {:ok, {2025, 2027}}
    end

    test "rejects other shapes and non-strings" do
      for value <- ["2026-27", "26-27", "2026/2027", " 2026-2027", "2026-2027 ", "", nil, 2026] do
        assert AcademicYear.parse(value) == :error
      end
    end
  end

  describe "valid?/1" do
    test "accepts consecutive years" do
      assert AcademicYear.valid?("2026-2027")
    end

    test "rejects non-consecutive years and other shapes" do
      for value <- ["2025-2027", "2027-2026", "2026-2026", "2026-27", nil] do
        refute AcademicYear.valid?(value)
      end
    end
  end
end
