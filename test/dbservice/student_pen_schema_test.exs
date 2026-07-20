defmodule Dbservice.StudentPenSchemaTest do
  use Dbservice.DataCase, async: true

  test "PEN is nullable text with the named partial unique index" do
    assert %{rows: [["text", "YES"]]} =
             Repo.query!("""
             SELECT data_type, is_nullable
             FROM information_schema.columns
             WHERE table_name = 'student' AND column_name = 'pen_number'
             """)

    %{rows: [[definition]]} =
      Repo.query!("""
      SELECT indexdef
      FROM pg_indexes
      WHERE tablename = 'student'
        AND indexname = 'student_pen_number_unique_not_null'
      """)

    assert definition =~ "UNIQUE INDEX"
    assert definition =~ "(pen_number)"
    assert definition =~ "WHERE (pen_number IS NOT NULL)"
  end
end
