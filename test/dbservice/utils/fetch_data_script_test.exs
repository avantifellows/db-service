defmodule Dbservice.Utils.FetchDataScriptTest do
  use ExUnit.Case, async: true

  setup do
    root = Path.join(System.tmp_dir!(), "fetch-data-#{System.unique_integer([:positive])}")
    bin = Path.join(root, "bin")
    capture = Path.join(root, "capture")
    File.mkdir_p!(bin)
    File.mkdir_p!(capture)

    script = Path.join(root, "fetch-data.sh")
    File.cp!("utils/fetch-data.sh", script)
    File.chmod!(script, 0o755)

    File.write!(Path.join(root, ".env"), """
    FETCH_ENVIRONMENT=production
    TARGET_ENVIRONMENT=staging
    PROD_DB_HOST=prod
    PROD_DB_NAME=prod_db
    PROD_DB_USER=prod_user
    PROD_DB_PASSWORD=prod_password
    PROD_DB_PORT=5432
    STAGING_DB_HOST=staging
    STAGING_DB_NAME=staging_db
    STAGING_DB_USER=staging_user
    STAGING_DB_PASSWORD=staging_password
    STAGING_DB_PORT=5432
    LOCAL_DB_HOST=local
    LOCAL_DB_NAME=local_db
    LOCAL_DB_USER=local_user
    LOCAL_DB_PASSWORD=local_password
    DUMP_FILE=test_dump.sql
    """)

    write_executable(Path.join(bin, "pg_dump"), """
    #!/bin/bash
    printf '%s\n' "$@" > "$CAPTURE_DIR/pg_dump.args"
    for arg in "$@"; do
      case "$arg" in --file=*) printf dump > "${arg#--file=}" ;; esac
    done
    """)

    write_executable(Path.join(bin, "psql"), """
    #!/bin/bash
    printf '%s\n' "$@" >> "$CAPTURE_DIR/psql.args"
    """)

    on_exit(fn -> File.rm_rf!(root) end)

    %{bin: bin, capture: capture, script: script}
  end

  test "production-to-staging excludes all Holistic Mentorship table data", context do
    assert {_, 0} = run_script(context, "SYNC STAGING")

    assert "--exclude-table-data=public.holistic_mentorship_*" in captured_args(
             context,
             "pg_dump.args"
           )
  end

  test "production-to-local remains available without the Holistic exclusion", context do
    set_environments(context, "production", "local")

    assert {_, 0} = run_script(context, "y")

    refute "--exclude-table-data=public.holistic_mentorship_*" in captured_args(
             context,
             "pg_dump.args"
           )
  end

  test "invalid source is rejected before database commands run", context do
    set_environments(context, "invalid", "local")

    assert {output, status} = run_script(context, "y")
    assert status != 0
    assert output =~ "Invalid FETCH_ENVIRONMENT 'invalid'"
    refute File.exists?(Path.join(context.capture, "pg_dump.args"))
  end

  test "invalid target is rejected before database commands run", context do
    set_environments(context, "production", "invalid")

    assert {output, status} = run_script(context, "y")
    assert status != 0
    assert output =~ "Invalid TARGET_ENVIRONMENT 'invalid'"
    refute File.exists?(Path.join(context.capture, "pg_dump.args"))
  end

  test "production cannot be used as a sync target", context do
    set_environments(context, "production", "production")

    assert {output, status} = run_script(context, "y")
    assert status != 0
    assert output =~ "Production cannot be used as a sync target"
    refute File.exists?(Path.join(context.capture, "pg_dump.args"))
  end

  defp run_script(context, confirmation) do
    System.cmd(
      "bash",
      ["-c", "printf '%s\\n' \"$2\" | bash \"$1\"", "_", context.script, confirmation],
      env: [
        {"PATH", "#{context.bin}:#{System.fetch_env!("PATH")}"},
        {"CAPTURE_DIR", context.capture}
      ],
      stderr_to_stdout: true
    )
  end

  defp captured_args(context, file) do
    context.capture
    |> Path.join(file)
    |> File.read!()
    |> String.split("\n", trim: true)
  end

  defp set_environments(context, source, target) do
    env_file = Path.join(Path.dirname(context.script), ".env")

    contents =
      env_file
      |> File.read!()
      |> String.replace("FETCH_ENVIRONMENT=production", "FETCH_ENVIRONMENT=#{source}")
      |> String.replace("TARGET_ENVIRONMENT=staging", "TARGET_ENVIRONMENT=#{target}")

    File.write!(env_file, contents)
  end

  defp write_executable(path, contents) do
    File.write!(path, contents)
    File.chmod!(path, 0o755)
  end
end
