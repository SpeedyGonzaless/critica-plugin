#!/bin/bash
# PreToolUse hook: blocks Read/Glob/Grep access outside the workspace.
# This is the plugin's security boundary — it cannot be overridden by REVIEW.md or prompt injection.
#
# Fails CLOSED: if the workspace (cwd) is unknown, or a path resolves outside it, the call is denied.
# Path canonicalization is purely LEXICAL (no `realpath`) so it is portable (macOS /bin/bash 3.2, no
# GNU coreutils) and works on paths that don't exist yet (e.g. Glob/Grep targets).

set -euo pipefail
set -f   # no globbing: path segments like `*` must never expand against the filesystem

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""')

# Emit a "deny" decision (current PreToolUse hook schema) and stop. `jq -n --arg` encodes the
# reason safely. Exit 0 — a deny is a policy decision, not a hook error (exit 2 is for errors).
deny() {
  jq -n --arg reason "$1" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason}}'
  exit 0
}

# Lexically canonicalize a path: make it absolute against CWD, then collapse `.`, `..`, and empty
# (`//`) segments without touching the filesystem. Prints the canonical absolute path.
canonicalize() {
  local path="$1" res="" seg IFS=/
  case "$path" in
    /*) ;;                  # already absolute
    *)  path="$CWD/$path" ;;
  esac
  for seg in $path; do
    case "$seg" in
      ''|.) ;;                  # skip empty + current-dir
      ..)   res="${res%/*}" ;;  # parent: drop last segment (clamped at root)
      *)    res="$res/$seg" ;;
    esac
  done
  printf '%s' "${res:-/}"
}

# Only Read/Glob/Grep carry a filesystem path worth checking.
case "$TOOL_NAME" in
  Read)  CHECK_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""') ;;
  Glob)  CHECK_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.path // ""') ;;
  Grep)  CHECK_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.path // ""') ;;
  *)     exit 0 ;;
esac

# No path given — the tool operates on cwd, which is in-bounds by definition.
if [ -z "$CHECK_PATH" ]; then
  exit 0
fi

# Fail closed: without a known workspace we cannot prove containment.
if [ -z "$CWD" ]; then
  deny "Cannot validate '$CHECK_PATH': workspace (cwd) is unknown"
fi

RESOLVED=$(canonicalize "$CHECK_PATH")
ROOT=$(canonicalize "$CWD")

# In-bounds iff RESOLVED is the workspace root itself, or sits beneath it. The trailing slash on
# "$ROOT/" (and the literal-quoted prefix) stops a sibling like /ws-evil from matching root /ws.
if [ "$RESOLVED" != "$ROOT" ] && [ "${RESOLVED#"$ROOT"/}" = "$RESOLVED" ]; then
  deny "Access denied: $CHECK_PATH is outside the workspace"
fi

exit 0
