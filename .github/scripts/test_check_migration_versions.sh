#!/usr/bin/env bash
# Tests for check_migration_versions.sh. Each case builds a throwaway git repo
# with a "main" commit and a feature branch, and puts a fake gh on PATH that
# answers from JSON fixtures (filtered through the script's own --jq, using jq).
#
# Usage: .github/scripts/test_check_migration_versions.sh

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/check_migration_versions.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" << 'EOF'
#!/usr/bin/env bash
# Fake gh. $FIXTURES/prs.json lists the open PRs as
#   [{number, headRefName, isCrossRepository, files: [{path, changeType, sha}],
#     extra_files: [...], rest_fails: bool}]
# "api graphql" serves them in GraphQL shape (files only, more = extra_files
# exist); "api .../pulls/N/files" serves files + extra_files in REST shape.
# Missing fixtures, rest_fails and unknown calls fail.
set -euo pipefail
jq_expr="."
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) jq_expr="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done
echo "${args[*]}" >> "$FIXTURES/calls.log"
fixture="$FIXTURES/prs.json"
[ -f "$fixture" ] || { echo "fake gh: no fixture $fixture" >&2; exit 1; }
if [ "${args[0]} ${args[1]}" = "api graphql" ]; then
  jq '{data: {repository: {pullRequests: {pageInfo: {hasNextPage: false, endCursor: null},
       nodes: map({number, headRefName, isCrossRepository,
                   files: {pageInfo: {hasNextPage: ((.extra_files // []) | length > 0)},
                           nodes: [(.files // [])[] | {path, changeType}]}})}}}}' "$fixture" |
    jq -r "$jq_expr"
elif [ "${args[0]} ${args[1]}" = "api --paginate" ] && [[ "${args[2]}" =~ /pulls/([0-9]+)/files ]]; then
  jq -e --argjson n "${BASH_REMATCH[1]}" '.[] | select(.number == $n) | select(.rest_fails | not)' "$fixture" > /dev/null ||
    { echo "fake gh: REST files for #${BASH_REMATCH[1]} failed" >&2; exit 1; }
  jq --argjson n "${BASH_REMATCH[1]}" '[.[] | select(.number == $n) | ((.files // []) + (.extra_files // []))[]
       | {filename: .path, sha: (.sha // "unknown"),
          status: ({ADDED: "added", MODIFIED: "modified", DELETED: "removed", RENAMED: "renamed",
                    COPIED: "copied", CHANGED: "changed"}[.changeType])}]' "$fixture" |
    jq -r "$jq_expr"
else
  echo "fake gh: unexpected call: ${args[*]}" >&2
  exit 1
fi
EOF
chmod +x "$WORK/bin/gh"

pass=0
failures=0
case_no=0

M=priv/repo/migrations

migration() { # path module-suffix
  mkdir -p "$(dirname "$1")"
  printf 'defmodule Dbservice.Repo.Migrations.%s do\n  use Ecto.Migration\n  def change, do: :ok\nend\n' "$2" > "$1"
}

# A repo whose main has two migrations, checked out on branch "feature".
new_repo() {
  case_no=$((case_no + 1))
  REPO="$WORK/case$case_no"
  export FIXTURES="$REPO.fixtures"
  mkdir -p "$REPO" "$FIXTURES"
  : > "$FIXTURES/calls.log"
  echo "[]" > "$FIXTURES/prs.json"
  cd "$REPO"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  migration "$M/20261001120000_create_a.exs" CreateA
  migration "$M/20261002120000_create_b.exs" CreateB
  printf '[import_deps: [:ecto_sql], inputs: ["*.exs"]]\n' > "$M/.formatter.exs"
  git add -A && git commit -qm main
  git checkout -qb feature
}

commit() { git add -A && git commit -qm change; }

open_prs() { # JSON array, see the fake gh above
  printf '%s\n' "$1" > "$FIXTURES/prs.json"
}
blob() { git hash-object "$1"; }

# run NAME EXPECTED_EXIT PATTERN... : runs the check, asserts exit status and
# that the output contains every pattern.
run() {
  local name="$1" expected="$2"
  shift 2
  local out status=0
  out="$(cd "$REPO" && PATH="$WORK/bin:$PATH" BASE_REF=main GH_REPO=org/repo GITHUB_ACTIONS='' RETRY_DELAY=0 \
    "$SCRIPT" 2>&1)" || status=$?
  local ok=1
  [ "$status" = "$expected" ] || ok=0
  for pattern in "$@"; do
    printf '%s\n' "$out" | grep -qF -- "$pattern" || ok=0
  done
  if [ "$ok" = 1 ]; then
    pass=$((pass + 1))
    echo "ok   - $name"
  else
    failures=$((failures + 1))
    echo "FAIL - $name (exit $status, expected $expected)"
    printf '%s\n' "$out" | sed 's/^/       /'
  fi
}

# --- no collision ------------------------------------------------------------
new_repo
migration "$M/20261103093412_add_c.exs" AddC
commit
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261104101733_add_d.exs", "changeType": "ADDED"},
                      {"path": "lib/foo.ex", "changeType": "MODIFIED"}]}]'
run "no collision passes" 0 "No migration version collisions." "Compared with 1 other open PR(s)"

# --- no new migrations: GitHub is not called ---------------------------------
new_repo
echo "# docs" > README.md
commit
run "branch without new migrations skips the API" 0 "adds no migrations"
[ ! -s "$FIXTURES/calls.log" ] || { failures=$((failures + 1)); echo "FAIL - gh was called: $(cat "$FIXTURES/calls.log")"; }

# --- duplicate version in the tree -------------------------------------------
new_repo
migration "$M/20261002120000_add_c.exs" AddC
commit
run "duplicate version in the tree fails" 1 \
  "ERROR: $M/20261002120000_add_c.exs: migration version 20261002120000 is also used by $M/20261002120000_create_b.exs" \
  "ERROR: $M/20261002120000_create_b.exs: migration version 20261002120000"

# --- duplicate version that differs only by leading zeros (Ecto parses ints) --
new_repo
migration "$M/020261002120000_add_c.exs" AddC
commit
run "leading-zero duplicate version fails" 1 "migration version 20261002120000 is also used by"

# --- duplicate version in a subdirectory (Ecto globs **/*.exs) ---------------
new_repo
migration "$M/archive/20261001120000_old_a.exs" OldA
commit
run "duplicate version in a subdirectory fails" 1 "migration version 20261001120000 is also used by"

# --- duplicate name in the tree ----------------------------------------------
new_repo
migration "$M/20261103093412_create_a.exs" CreateA2
commit
run "duplicate name in the tree fails" 1 "migration name create_a is also used by"

# --- collision with another open PR ------------------------------------------
new_repo
migration "$M/20261103120000_add_c.exs" AddC
commit
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261103120000_add_school_columns.exs", "changeType": "ADDED"}]},
           {"number": 905, "headRefName": "feature", "isCrossRepository": false, "files": []}]'
PR_NUMBER=905 run "collision with an open PR fails" 1 \
  "ERROR: $M/20261103120000_add_c.exs: migration version 20261103120000 is also used by PR #900 ($M/20261103120000_add_school_columns.exs)" \
  "normally the newer one, this PR" "Found 1 migration version problem(s)."
PR_NUMBER=850 run "collision names the newer PR" 1 "normally the newer one, #900"

# --- a rename in the other PR counts as adding --------------------------------
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261103120000_add_e.exs", "changeType": "RENAMED"}]}]'
run "collision with a renamed file in an open PR fails" 1 "is also used by PR #900" "normally the newer one, this branch"

# --- the other PR deleting or editing a same-version file is not a collision --
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261103120000_other.exs", "changeType": "DELETED"},
                      {"path": "priv/repo/migrations/20261103120000_more.exs", "changeType": "MODIFIED"}]}]'
run "deleted or modified file in another PR is ignored" 0 "No migration version collisions."

# --- a PR with over 100 files is listed in full over REST ---------------------
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "lib/foo.ex", "changeType": "MODIFIED"}],
            "extra_files": [{"path": "priv/repo/migrations/20261103120000_late.exs", "changeType": "ADDED"}]}]'
run "collision past the first 100 files fails" 1 "is also used by PR #900 ($M/20261103120000_late.exs)"

# --- this PR itself is left out (by number in CI, by branch locally) ---------
open_prs '[{"number": 905, "headRefName": "feature", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261103120000_add_c_old_name.exs", "changeType": "ADDED"}]}]'
PR_NUMBER=905 run "own PR is excluded by PR_NUMBER" 0 "Compared with 0 other open PR(s)"
run "own PR is excluded by branch name locally" 0 "Compared with 0 other open PR(s)"

# --- a fork PR with the same branch name is still compared locally -----------
open_prs '[{"number": 905, "headRefName": "feature", "isCrossRepository": true,
            "files": [{"path": "priv/repo/migrations/20261103120000_add_c_old_name.exs", "changeType": "ADDED"}]}]'
run "fork PR with the same branch name is compared" 1 "is also used by PR #905"

# --- stacked PR: the other PR carries the very same file ----------------------
new_repo
migration "$M/20261103120000_add_c.exs" AddC
commit
sha="$(git hash-object "$M/20261103120000_add_c.exs")"
open_prs "[{\"number\": 900, \"headRefName\": \"base-feature\", \"isCrossRepository\": false,
            \"files\": [{\"path\": \"$M/20261103120000_add_c.exs\", \"changeType\": \"ADDED\", \"sha\": \"$sha\"}]}]"
run "same file in a stacked PR is not a collision" 0 "is not a collision"
open_prs "[{\"number\": 900, \"headRefName\": \"base-feature\", \"isCrossRepository\": false,
            \"files\": [{\"path\": \"$M/20261103120000_add_c.exs\", \"changeType\": \"ADDED\", \"sha\": \"different\"}]}]"
run "same file with different content warns" 0 \
  "WARNING: $M/20261103120000_add_c.exs: PR #900 adds this same migration file with different content"

# --- same name, different version in another PR warns -------------------------
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false,
            "files": [{"path": "priv/repo/migrations/20261104101733_add_c.exs", "changeType": "ADDED"}]}]'
run "same name in another PR warns" 0 "WARNING: $M/20261103120000_add_c.exs: PR #900 adds a migration with the same name"

# --- GitHub annotations in Actions --------------------------------------------
new_repo
migration "$M/20261002120000_add_c.exs" AddC
commit
out="$(cd "$REPO" && { GITHUB_ACTIONS=true SKIP_OPEN_PRS=1 "$SCRIPT" 2>&1 || true; })"
if printf '%s\n' "$out" | grep -qF "::error file=$M/20261002120000_add_c.exs::migration version 20261002120000"; then
  pass=$((pass + 1)); echo "ok   - emits ::error annotations in Actions"
else
  failures=$((failures + 1)); echo "FAIL - no ::error annotation"; printf '%s\n' "$out"
fi

# --- SKIP_OPEN_PRS still checks the tree, and never calls GitHub -------------
SKIP_OPEN_PRS=1 run "SKIP_OPEN_PRS still fails on a tree duplicate" 1 "migration version 20261002120000 is also used by"

new_repo
migration "$M/20261103120000_add_c.exs" AddC
commit
SKIP_OPEN_PRS=1 run "SKIP_OPEN_PRS skips the API" 0 "Skipping the open-PR comparison"
[ ! -s "$FIXTURES/calls.log" ] || { failures=$((failures + 1)); echo "FAIL - gh was called with SKIP_OPEN_PRS=1"; }

# --- GitHub errors make the check error out (exit 2), not pass ---------------
rm "$FIXTURES/prs.json"
run "failed PR listing exits 2" 2 "could not list open PRs to main"
open_prs '[{"number": 900, "headRefName": "other", "isCrossRepository": false, "rest_fails": true,
            "files": [], "extra_files": [{"path": "lib/foo.ex", "changeType": "MODIFIED"}]}]'
run "failed PR files listing exits 2" 2 "could not list the files of PR #900"

echo
echo "$pass passed, $failures failed"
[ "$failures" -eq 0 ]
