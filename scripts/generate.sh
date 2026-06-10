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

gen_agent() {
  local area="$1" name="$2" desc="$3"
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
}

mkdir -p "${CLAUDE_DIR}/agents"
gen_agent logic      critica-logic      "Reviews code changes for logical errors and correctness bugs"
gen_agent security   critica-security   "Reviews code changes for security vulnerabilities"
gen_agent edge-cases critica-edge-cases "Reviews code changes for edge cases and error handling gaps"

# To add a new analysis area: (1) add content/<area>.md, (2) add a gen_agent call above,
# (3) add a matching `printf '\n## Focus: …\n\n'; cat content/<area>.md` stanza below.
# Keep `content/*.md` descriptions YAML-safe (no leading YAML-special chars, no ": " sequences).
# Codex skill — one SKILL.md that orchestrates three subagents from the same content.
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
  printf '\n## Focus: logic & correctness (critica-logic)\n\n';      cat content/logic.md
  printf '\n## Focus: security (critica-security)\n\n';              cat content/security.md
  printf '\n## Focus: edge cases & error handling (critica-edge-cases)\n\n'; cat content/edge-cases.md
  printf '\n'; cat content/common.md
} > "${CODEX_DIR}/skills/critica-review/SKILL.md"

echo "Generated:" "${CLAUDE_DIR}"/agents/critica-{logic,security,edge-cases}.md "${CODEX_DIR}/skills/critica-review/SKILL.md"
