#!/bin/bash
# PreToolUse hook: blocks Read/Glob/Grep access outside the workspace.
# Cannot be overridden by REVIEW.md or any prompt injection.

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

# Extract the path to check based on tool type
case "$TOOL_NAME" in
  Read)  CHECK_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""') ;;
  Glob)  CHECK_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // ""') ;;
  Grep)  CHECK_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // ""') ;;
  *)     exit 0 ;;
esac

# Empty or missing path — tool will use cwd, which is fine
if [ -z "$CHECK_PATH" ]; then
  exit 0
fi

# Resolve to absolute path
RESOLVED=$(realpath -m "$CHECK_PATH" 2>/dev/null || echo "$CHECK_PATH")

# Block if path escapes the workspace
if [[ "$RESOLVED" != "$CWD"* ]]; then
  echo "{\"decision\": \"block\", \"reason\": \"Access denied: $CHECK_PATH is outside the workspace\"}"
fi
