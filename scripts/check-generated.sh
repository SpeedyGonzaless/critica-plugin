#!/usr/bin/env bash
# Fails if the committed generated files are out of sync with content/.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/generate.sh >/dev/null
GENERATED="plugins/critica-claude/agents plugins/critica-codex/skills"
# Use porcelain (not `git diff`) so a NEW untracked generated file — e.g. a freshly
# added analysis area whose agents/<name>.md wasn't committed — also counts as drift.
drift="$(git status --porcelain -- $GENERATED)"
if [ -n "$drift" ]; then
  echo "ERROR: generated files are out of date. Run ./scripts/generate.sh and commit." >&2
  echo "$drift" >&2
  git --no-pager diff -- $GENERATED >&2
  # `git diff` doesn't show untracked files — print new generated files in full.
  # NUL-delimited so paths with spaces/quotes are handled correctly.
  git ls-files --others --exclude-standard -z -- $GENERATED | while IFS= read -r -d '' f; do
    echo "--- new (untracked) generated file: $f" >&2
    cat "$f" >&2
  done
  exit 1
fi
echo "OK: generated files match content/."
