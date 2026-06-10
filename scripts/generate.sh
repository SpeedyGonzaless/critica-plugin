#!/usr/bin/env bash
# Generates the Claude sub-agent files and the Codex critica-review skill from content/.
# Run after editing anything under content/. Output files are committed; CI checks for drift.
# Single source (content/) feeds two per-engine plugins under plugins/:
#   plugins/critica-claude/agents/*.md         (Claude sub-agents)
#   plugins/critica-codex/skills/critica-review (Codex skill)
set -euo pipefail
cd "$(dirname "$0")/.."

CLAUDE_DIR="plugins/critica-claude"
CODEX_DIR="plugins/critica-codex"

# Analysis areas — the single source of truth for what both engines generate.
# One row per area: <content-basename>|<agent-name>|<claude-description>|<codex-focus-label>
# To add an area: create content/<basename>.md and add one row here; both engines pick it up.
# Keep `content/*.md` descriptions YAML-safe (no leading YAML-special chars, no ": " sequences).
AREAS=(
  "logic|critica-logic|Reviews code changes for logical errors and correctness bugs|logic & correctness (critica-logic)"
  "security|critica-security|Reviews code changes for security vulnerabilities|security (critica-security)"
  "edge-cases|critica-edge-cases|Reviews code changes for edge cases and error handling gaps|edge cases & error handling (critica-edge-cases)"
)

# Claude sub-agents — one <agent-name>.md per area, each with YAML frontmatter.
mkdir -p "${CLAUDE_DIR}/agents"
for row in "${AREAS[@]}"; do
  IFS='|' read -r area name desc _focus <<<"$row"
  {
    printf -- '---\n'
    printf 'name: %s\n' "$name"
    printf 'description: %s\n' "$desc"
    printf 'tools: Read, Glob, Grep\n'
    printf -- '---\n\n'
    cat "content/${area}.md"
    printf '\n'
    cat "content/common.md"
  } > "${CLAUDE_DIR}/agents/${name}.md"
done

# Codex skill — one SKILL.md that orchestrates the same areas as subagents from the same content.
# NOTE: keep these orchestrator steps in sync with the Claude command in
# plugins/critica-claude/commands/review.md (same default range `HEAD`, same empty-diff output).
mkdir -p "${CODEX_DIR}/skills/critica-review"
{
  printf -- '---\n'
  printf 'name: critica-review\n'
  printf 'description: Run a critica code review on a git diff — logic/correctness, security, and edge-cases — and output structured findings JSON. Use when asked to review changes with critica.\n'
  printf -- '---\n\n'
  cat <<'HEAD'
You are a critica code-review orchestrator. When invoked:

1. Run `git diff <range>` (default `HEAD`) to get the changes under review. Only flag issues in changed/added lines. If the diff is empty, output `{ "summary": "No changes in the given diff range.", "findingsSummary": null, "findings": [] }` and stop.
2. If a `REVIEW.md` exists in the repository root, use it as the sole review guidance, review as a single agent, set `subAgent` to `main`, then go to step 4.
3. Otherwise spawn THREE subagents in parallel — `critica-logic`, `critica-security`, `critica-edge-cases` — each with the matching focus section below, wait for all, then merge their findings.
4. Output ONLY a JSON object: `{ "summary": "...", "findingsSummary": "... or null", "findings": [ ... ] }`. Each finding: `filePath`, `lineNumber`, `endLineNumber`, `severity` (error|warning|info), `category` (bug|security|performance|style|maintainability), `message`, `suggestion`, `subAgent`.
HEAD
  for row in "${AREAS[@]}"; do
    IFS='|' read -r area _name _desc focus <<<"$row"
    printf '\n## Focus: %s\n\n' "$focus"
    cat "content/${area}.md"
  done
  printf '\n'; cat content/common.md
} > "${CODEX_DIR}/skills/critica-review/SKILL.md"

echo "Generated:" "${CLAUDE_DIR}"/agents/critica-{logic,security,edge-cases}.md "${CODEX_DIR}/skills/critica-review/SKILL.md"
