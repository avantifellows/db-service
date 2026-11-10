#!/usr/bin/env bash
# Fail when an Ecto migration version is used twice: by two files in this tree,
# or by this branch and another open PR to main.
#
# schema_migrations records only the version. A database that has already run
# one file with a version silently skips every other file with that version
# ("Migrations already up"). Ecto raises "migration version X is duplicated"
# only when both files are pending at once, which in practice means a fresh
# database. Staging auto-deploys every PR to main, so two open PRs that pick the
# same version leave one of them unapplied there (#792).
#
# Usage (from anywhere in the repo):
#   .github/scripts/check_migration_versions.sh
#
# Env:
#   MIGRATIONS_DIR  migrations directory, relative to the repo root
#                   (default priv/repo/migrations)
#   BASE_REF        git ref this branch merges into. Migrations in the working
#                   tree but not in BASE_REF are the ones this branch adds.
#                   (default origin/main; CI uses HEAD^1 of the PR merge commit)
#   TARGET_BRANCH   open PRs to this base branch are compared (default main)
#   GH_REPO         owner/repo (default: the repo gh resolves from the remote)
#   PR_NUMBER       this branch's PR, left out of the comparison. When unset,
#                   open PRs whose head is the current branch are left out.
#   SKIP_OPEN_PRS   1 = check only the tree, without calling GitHub
#   RETRY_DELAY     seconds between GitHub retries, times the attempt (default 3)
#
# Needs git, and gh for the open-PR comparison.
# Exit status: 0 no collision, 1 collision found, 2 the check could not run.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

MIGRATIONS_DIR="${MIGRATIONS_DIR:-priv/repo/migrations}"
MIGRATIONS_DIR="${MIGRATIONS_DIR%/}"
BASE_REF="${BASE_REF:-origin/main}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
PR_NUMBER="${PR_NUMBER:-}"

TAB=$'\t'
errors=0

annotate() { # level file message
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::$1 file=$2::$3"
  else
    echo "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]'): $2: $3"
  fi
}
fail() { errors=$((errors + 1)); annotate error "$1" "$2"; }
warn() { annotate warning "$1" "$2"; }
die() { echo "check_migration_versions: $*" >&2; exit 2; }
stop_if_errors() {
  if [ "$errors" -gt 0 ]; then
    echo "Found $errors migration version problem(s)."
    exit 1
  fi
}

# Read migration paths on stdin and print "version<TAB>name<TAB>path".
# Matches Ecto.Migrator: <integer>_<name>.exs anywhere under the directory
# (.ex files and files without a leading integer are not migrations). The
# version is compared as an integer, as Ecto does.
parse_migrations() {
  local path base
  while IFS= read -r path; do
    base="${path##*/}"
    if [[ "$base" =~ ^([0-9]+)_(.+)\.exs$ ]]; then
      printf '%s\t%s\t%s\n' "$((10#${BASH_REMATCH[1]}))" "${BASH_REMATCH[2]}" "$path"
    fi
  done
}

[ -d "$MIGRATIONS_DIR" ] || die "no migrations directory at $MIGRATIONS_DIR"

tree="$(find "$MIGRATIONS_DIR" -type f -name '*.exs' | sort | parse_migrations)"

# Migrations already in BASE_REF have been merged and may have run on staging
# and prod; the rest are new on this branch. The tree check words its advice
# by that, and works without it when BASE_REF is missing.
base_known=0
base_paths=""
if git rev-parse --verify --quiet "$BASE_REF^{commit}" > /dev/null; then
  base_known=1
  base_paths="$(git ls-tree -r --name-only "$BASE_REF" -- "$MIGRATIONS_DIR")"
fi

rename_new="to an unused timestamp from 'mix ecto.gen.migration' (not a round ...120000 one)"
rename_merged="Both are already merged, so a database that ran one has probably skipped the other. Check schema_migrations on staging and prod to see which was skipped, and rename that one $rename_new. A renamed migration is pending again everywhere, so it also re-runs wherever it did run: rename it only if it is safe to run twice (guarded or idempotent), or insert its new version into schema_migrations on those databases first."

# 1. No version or name may appear twice in this tree. On a PR this is the
#    merge of the PR into its base, so it also catches a clash with main.
#    Every file in a clash is annotated; the clash counts as one problem.
for field in 1 2; do
  [ "$field" = 1 ] && what=version || what=name
  for dup in $(printf '%s\n' "$tree" | cut -f"$field" | sort | uniq -d); do
    files="$(printf '%s\n' "$tree" | awk -F'\t' -v f="$field" -v d="$dup" '$f == d { print $3 }')"
    new_files=""
    if [ "$base_known" = 1 ]; then
      new_files="$(printf '%s\n' "$files" | grep -vxF -f <(printf '%s\n' "$base_paths") || true)"
    fi
    if [ "$field" = 2 ]; then
      why="Ecto refuses to run two pending migrations with the same name. Rename one."
    elif [ "$base_known" = 1 ] && [ -z "$new_files" ]; then
      why="$rename_merged"
    elif [ -n "$new_files" ] && [ "$(printf '%s\n' "$new_files" | wc -l)" -lt "$(printf '%s\n' "$files" | wc -l)" ]; then
      why="A database that has run one of these files records the version and silently skips the other. Rename the one this branch adds ($(printf '%s\n' "$new_files" | paste -sd ' ' -)) $rename_new."
    else
      why="A database that has run one of these files records the version and silently skips the other. Rename one $rename_new."
    fi
    for file in $files; do
      others="$(printf '%s\n' "$files" | grep -vxF "$file" | tr '\n' ' ')"
      annotate error "$file" "migration $what $dup is also used by ${others% }. $why"
    done
    errors=$((errors + 1))
  done
done

count="$(printf '%s\n' "$tree" | grep -c . || true)"
echo "Checked $count migrations in $MIGRATIONS_DIR for duplicate versions and names."

if [ "${SKIP_OPEN_PRS:-}" = 1 ]; then
  stop_if_errors
  echo "Skipping the open-PR comparison (SKIP_OPEN_PRS=1)."
  exit 0
fi

# 2. Migrations this branch adds must not share a version with migrations that
#    another open PR to TARGET_BRANCH adds.
[ "$base_known" = 1 ] ||
  die "base ref '$BASE_REF' not found (fetch it, or set BASE_REF)"

added="$(printf '%s\n' "$tree" | awk -F'\t' 'NR == FNR { base[$0] = 1; next } !($3 in base)' \
  <(printf '%s\n' "$base_paths") - | grep . || true)"

if [ -z "$added" ]; then
  echo "This branch adds no migrations relative to $BASE_REF; nothing to compare with open PRs."
  stop_if_errors
  exit 0
fi

echo "This branch adds:"
printf '%s\n' "$added" | cut -f3 | sed 's/^/  /'

command -v gh > /dev/null || die "gh is required for the open-PR comparison (or set SKIP_OPEN_PRS=1)"

repo="${GH_REPO:-}"
if [ -z "$repo" ]; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)" || die "could not resolve the repo; set GH_REPO"
fi

current_branch=""
if [ -z "$PR_NUMBER" ]; then
  current_branch="$(git symbolic-ref --short -q HEAD || true)"
fi

# gh with retries: the API occasionally drops a connection.
gh_retry() {
  local out attempt
  for attempt in 1 2 3; do
    if out="$(gh "$@")"; then
      printf '%s\n' "$out"
      return 0
    fi
    [ "$attempt" = 3 ] || sleep $((attempt * ${RETRY_DELAY:-3}))
  done
  return 1
}

# Migrations a PR adds (or renames/copies into place), as "path<TAB>blob sha".
pr_files() {
  gh_retry api --paginate "repos/$repo/pulls/$1/files?per_page=100" \
    --jq ".[] | select(.status == \"added\" or .status == \"renamed\" or .status == \"copied\")
              | select(.filename | startswith(\"$MIGRATIONS_DIR/\")) | [.filename, .sha] | @tsv"
}

# Every open PR to TARGET_BRANCH with its first 100 files, in one paginated
# query: "number<TAB>head<TAB>cross-repo<TAB>more files?<TAB>added migration paths".
# shellcheck disable=SC2016 # GraphQL variables, not shell ones
query='query($owner: String!, $name: String!, $base: String!, $endCursor: String) {
  repository(owner: $owner, name: $name) {
    pullRequests(states: OPEN, baseRefName: $base, first: 50, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        headRefName
        isCrossRepository
        files(first: 100) { pageInfo { hasNextPage } nodes { path changeType } }
      }
    }
  }
}'
prs="$(gh_retry api graphql --paginate -f query="$query" \
  -f owner="${repo%%/*}" -f name="${repo#*/}" -f base="$TARGET_BRANCH" \
  --jq ".data.repository.pullRequests.nodes[]
        | [.number, .headRefName, .isCrossRepository, .files.pageInfo.hasNextPage,
           ([(.files.nodes // [])[]
             | select(.changeType == \"ADDED\" or .changeType == \"RENAMED\" or .changeType == \"COPIED\")
             | select(.path | startswith(\"$MIGRATIONS_DIR/\")) | .path] | join(\" \"))]
        | @tsv")" ||
  die "could not list open PRs to $TARGET_BRANCH in $repo"

compared=0
while IFS="$TAB" read -r number head cross more paths; do
  [ -n "$number" ] || continue
  if [ -n "$PR_NUMBER" ]; then
    [ "$number" = "$PR_NUMBER" ] && continue
  elif [ -n "$current_branch" ] && [ "$head" = "$current_branch" ] && [ "$cross" = false ]; then
    continue
  fi
  compared=$((compared + 1))

  if [ "$more" = true ]; then
    # Over 100 files: list them all over REST.
    their_files="$(pr_files "$number")" || die "could not list the files of PR #$number"
  else
    their_files="$(for p in $paths; do printf '%s\t\n' "$p"; done)"
  fi
  [ -n "$their_files" ] || continue

  while IFS="$TAB" read -r their_path their_sha; do
    their="$(printf '%s\n' "$their_path" | parse_migrations)"
    [ -n "$their" ] || continue
    their_version="$(cut -f1 <<< "$their")"
    their_name="$(cut -f2 <<< "$their")"

    while IFS="$TAB" read -r version name path; do
      if [ "$version" = "$their_version" ]; then
        if [ "$path" = "$their_path" ]; then
          # The same file in both PRs: one branch is built on the other.
          if [ -z "$their_sha" ]; then
            their_sha="$(pr_files "$number" | awk -F'\t' -v p="$path" '$1 == p { print $2 }')" ||
              die "could not list the files of PR #$number"
          fi
          if [ "$(git hash-object "$path")" != "$their_sha" ]; then
            warn "$path" "PR #$number adds this same migration file with different content. Whichever version reaches staging first is the one that runs there."
          else
            echo "Note: PR #$number adds the same file $path (one branch is built on the other), so it is not a collision."
          fi
          continue
        fi
        if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" -gt "$number" ]; then
          newer="this PR"
        elif [ -n "$PR_NUMBER" ]; then
          newer="#$number"
        else
          newer="this branch"
        fi
        fail "$path" "migration version $version is also used by PR #$number ($their_path). Staging deploys every PR to $TARGET_BRANCH and records only the version, so whichever of the two runs second is silently skipped there (see #792). Rename the migration in the PR that has not run on staging yet (normally the newer one, $newer) to an unused timestamp from 'mix ecto.gen.migration' (not a round ...120000 one)."
      elif [ "$name" = "$their_name" ]; then
        warn "$path" "PR #$number adds a migration with the same name ($their_path). Once both merge, Ecto refuses to run them together on a fresh database. Consider renaming one."
      fi
    done <<< "$added"
  done <<< "$their_files"
done <<< "$prs"

echo "Compared with $compared other open PR(s) to $TARGET_BRANCH in $repo."

stop_if_errors
echo "No migration version collisions."
