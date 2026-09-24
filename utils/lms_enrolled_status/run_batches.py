#!/usr/bin/env python3
"""Run one reviewed wave of a status utility: report 500, apply in batches of 100, check each rerun.

Every step goes through the utility's own CLI, so the hash approval, database binding,
revalidation and rollback rules are unchanged. Stops at the first failure.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).parent
GROUPS = ("repair", "cancel_accidental_dropout", "backfill_before_dropout",
          "remaining_cases", "approved_db_exception")
APPLIED = {"created", "corrected"}


def write_private(path, value):
    with open(path, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as output:
        json.dump(value, output, indent=2, default=str)
        output.write("\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", required=True, choices=GROUPS)
    parser.add_argument("--database", required=True)
    parser.add_argument("--remote", action="store_true")
    parser.add_argument("--actor", required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--max-students", type=int, required=True, help="Size of this wave")
    parser.add_argument("--batch-size", type=int, default=100)
    parser.add_argument("--pause", type=float, default=2.0, help="Seconds between batches")
    args = parser.parse_args()
    if not 1 <= args.batch_size <= 100 or args.max_students < 1:
        parser.error("batch-size must be 1..100 and max-students positive")
    args.out_dir.mkdir(mode=0o700, parents=True, exist_ok=False)
    step = 0

    def cli(*extra):
        nonlocal step
        step += 1
        output = args.out_dir / f"{step:04}.json"
        command = [sys.executable, str(HERE / f"{args.group}.py"), "--database", args.database,
                   "--output", str(output), *extra] + (["--remote"] if args.remote else [])
        started = time.monotonic()
        if subprocess.run(command, stdout=subprocess.DEVNULL).returncode:
            sys.exit(f"Stopped: step {step} failed ({' '.join(extra[:1])}); nothing after it ran")
        return json.loads(output.read_text()), output, time.monotonic() - started

    applied, batches, cursor, first_summary = 0, 0, 0, {}
    while applied < args.max_students:
        report, report_path, seconds = cli("--limit", "500", "--after-student-id", str(cursor))
        first_summary = first_summary or report["summary"]
        print(f"report after {cursor}: {len(report['rows'])} rows, eligible "
              f"{report['summary']['eligible_count']} ({seconds:.1f}s)", flush=True)
        if not report["rows"]:
            break
        report_sha = hashlib.sha256(report_path.read_bytes()).hexdigest()
        rows = report["rows"][:args.max_students - applied]
        for start in range(0, len(rows), args.batch_size):
            batch = dict(report, rows=rows[start:start + args.batch_size], parent_report_sha256=report_sha)
            step += 1
            batch_path = args.out_dir / f"{step:04}-batch.json"
            write_private(batch_path, batch)
            digest = hashlib.sha256(batch_path.read_bytes()).hexdigest()
            approval = ("--apply", str(batch_path), "--approve-sha256", digest, "--actor", args.actor)
            result, _, seconds = cli(*approval)
            if any(r["result"] not in APPLIED for r in result["verification"]):
                sys.exit(f"Stopped: batch {batch_path.name} had rows that were not newly applied")
            replay, _, _ = cli(*approval)
            if any(r["result"] != "already_applied" for r in replay["verification"]):
                sys.exit(f"Stopped: rerun of {batch_path.name} changed data")
            applied += len(batch["rows"])
            batches += 1
            print(f"batch {batches}: {len(batch['rows'])} applied, rerun clean, total {applied} ({seconds:.1f}s)", flush=True)
            time.sleep(args.pause)
        if not report["more_candidates"]:
            break
        cursor = rows[-1]["student_id"]

    final, _, _ = cli("--limit", "1")
    summary = {"group": args.group, "applied": applied, "batches": batches,
               "before": first_summary, "after": final["summary"]}
    write_private(args.out_dir / "summary.json", summary)
    print(json.dumps({"applied": applied, "batches": batches,
                      "eligible_before": first_summary["eligible_count"],
                      "eligible_after": final["summary"]["eligible_count"]}))


if __name__ == "__main__":
    main()
