"""Integration checks against disposable local PostgreSQL databases.

RUN_DB_SYNC_TESTS=1 PATH=<PostgreSQL-16-bin>:$PATH python3 -m unittest discover -s utils/tests
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import uuid


@unittest.skipUnless(os.environ.get("RUN_DB_SYNC_TESTS") == "1", "requires local PostgreSQL")
class FetchDataTests(unittest.TestCase):
    def sql(self, database, sql):
        return subprocess.check_output(["psql", "-X", "-h", "localhost", "-U", "postgres", "-d", database, "-At", "-v", "ON_ERROR_STOP=1", "-c", sql], text=True).strip()

    def setUp(self):
        self.source = "sync_test_src_" + uuid.uuid4().hex[:12]
        self.target = "sync_test_dst_" + uuid.uuid4().hex[:12]
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.script = self.root / "fetch-data.sh"
        shutil.copyfile(Path(__file__).parents[1] / "fetch-data.sh", self.script)
        for database in (self.source, self.target):
            self.sql("postgres", f'CREATE DATABASE "{database}"')
        for table in ("holistic_mentorship_student_profiles", "holistic_mentorship_privacy_deletions", "oban_jobs", "session", "session_occurrence", "group_session", "user_session"):
            self.sql(self.source, f'CREATE TABLE "{table}" (id integer); INSERT INTO "{table}" VALUES (1)')
        self.sql(self.target, "CREATE TABLE old_target (id integer); INSERT INTO old_target VALUES (9)")

    def tearDown(self):
        for database in (self.source, self.target):
            self.sql("postgres", f'DROP DATABASE "{database}" WITH (FORCE)')
        self.directory.cleanup()

    def run_sync(self, destination, fail=False):
        values = {"FETCH_ENVIRONMENT": "production", "TARGET_ENVIRONMENT": destination}
        for prefix, database in (("PROD", self.source), ("STAGING", self.target), ("LOCAL", self.target)):
            values.update({prefix + "_DB_HOST": "localhost", prefix + "_DB_PORT": "5432", prefix + "_DB_NAME": database, prefix + "_DB_USER": "postgres", prefix + "_DB_PASSWORD": "postgres"})
        config = self.root / ".env"
        config.write_text("\n".join(f"{k}={v}" for k,v in values.items()))
        env = os.environ.copy()
        env["DB_FETCH_ENV_FILE"] = str(config)
        if fail:
            real_dump = shutil.which("pg_dump")
            wrapper = self.root / "bin"
            wrapper.mkdir()
            stub = wrapper / "pg_dump"
            stub.write_text('#!/bin/bash\n"' + real_dump + '" "$@" || exit $?\nfor arg in "$@"; do case "$arg" in --file=*) printf "\\nSELECT missing_sync_test_function();\\n" >> "${arg#--file=}";; esac; done\n')
            stub.chmod(0o700)
            env["PATH"] = str(wrapper) + ":" + env["PATH"]
        return subprocess.run(["bash", str(self.script)], input="SYNC STAGING\n" if destination == "staging" else "y\n", text=True, capture_output=True, env=env)

    def test_local_keeps_holistic_and_sessions_but_not_jobs(self):
        result = self.run_sync("local")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("1", self.sql(self.target, "SELECT count(*) FROM holistic_mentorship_student_profiles"))
        self.assertEqual("1", self.sql(self.target, "SELECT count(*) FROM holistic_mentorship_privacy_deletions"))
        self.assertEqual("1", self.sql(self.target, "SELECT count(*) FROM session"))
        self.assertEqual("0", self.sql(self.target, "SELECT count(*) FROM oban_jobs"))
        self.assertFalse((self.root / "dump.sql").exists())

    def test_staging_keeps_holistic_but_not_sessions_or_jobs(self):
        result = self.run_sync("staging")
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertEqual("1", self.sql(self.target, "SELECT count(*) FROM holistic_mentorship_student_profiles"))
        self.assertEqual("1", self.sql(self.target, "SELECT count(*) FROM holistic_mentorship_privacy_deletions"))
        for table in ("session", "session_occurrence", "group_session", "user_session", "oban_jobs"):
            self.assertEqual("0", self.sql(self.target, f'SELECT count(*) FROM "{table}"'))

    def test_restore_error_rolls_back_and_retains_dump(self):
        result = self.run_sync("staging", fail=True)
        self.assertNotEqual(0, result.returncode)
        self.assertIn("rolled back", result.stdout)
        self.assertIn("missing_sync_test_function", result.stderr)
        self.assertNotIn("Database fetch completed successfully", result.stdout)
        self.assertEqual("9", self.sql(self.target, "SELECT id FROM old_target"))
        self.assertTrue((self.root / "dump.sql").exists())
