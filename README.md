# Critica — AI Code Review Plugin

AI-powered code review with specialized sub-agents for logic, security, and edge cases.

This repository is a **monorepo** that ships the same review content as two per-engine plugins,
generated from a single source (`content/`):

| Plugin | Engine | Path | Entry point |
|--------|--------|------|-------------|
| `critica` (Claude) | [Claude Code](https://code.claude.com) | `plugins/critica-claude/` | `/critica:review` command + sub-agents |
| `critica` (Codex)  | [OpenAI Codex](https://developers.openai.com/codex) | `plugins/critica-codex/` | `critica-review` skill (`codex exec`) |

Each plugin is self-contained under its own subdirectory so the two ecosystems never collide on the
shared `skills/`/`hooks/` folder names — Claude only sees `plugins/critica-claude/`, Codex only sees
`plugins/critica-codex/`.

## Prerequisites

- [jq](https://jqlang.github.io/jq/) — used by the Claude path-checking hook to parse JSON

## Installation

### Claude Code

```bash
claude plugin marketplace add mazurov/critica-plugin
claude plugin install critica@critica
```

(Or from inside Claude Code: `/plugin marketplace add mazurov/critica-plugin` then `/plugin install critica@critica`.)

### Codex

```bash
codex plugin marketplace add mazurov/critica-plugin
codex plugin add critica@critica
```

> Note: the Codex marketplace manifest (`.agents/plugins/marketplace.json`) follows the current
> `codex plugin` schema; validate with `codex plugin marketplace add` as the tooling is still new.

## Usage

### Claude Code

```bash
/critica:review            # review uncommitted changes (default HEAD)
/critica:review HEAD~1     # review last commit
/critica:review main..HEAD # review a range
```

### Codex

```bash
codex exec '$critica-review — review the changes in `git diff HEAD~1`'
```

Both produce the same structured findings JSON.

## How It Works

1. **Detects mode** — if `REVIEW.md` exists in the repo root, uses it as custom review guidance (direct mode, `subAgent` = `main`). Otherwise, uses specialized sub-agents (orchestrator mode).
2. **Gets the diff** — runs `git diff` with the provided range.
3. **Runs sub-agents in parallel** (orchestrator mode):
   - `critica-logic` — logical errors, bugs, correctness issues
   - `critica-security` — security vulnerabilities (OWASP, injection, auth)
   - `critica-edge-cases` — edge cases, error handling, boundary conditions
4. **Merges and verifies** findings against actual source code.
5. **Outputs** a JSON object: `{ "summary", "findingsSummary", "findings": [ ... ] }`.

## Custom Review Instructions

Create a `REVIEW.md` in your repository root to provide custom review guidance. When present, both
engines use your instructions as a single reviewer instead of the default sub-agents.

## Sub-Agents

Each sub-agent has restricted tools (`Read`, `Glob`, `Grep` only) and focused instructions:

| Agent | Focus |
|-------|-------|
| `critica-logic` | Logical errors, null refs, off-by-one, race conditions |
| `critica-security` | Injection, auth flaws, data exposure, OWASP Top 10 |
| `critica-edge-cases` | Boundary conditions, error handling, resource leaks |

## Output Format

```json
{
  "summary": "2-3 sentence summary of what changed",
  "findingsSummary": "1-2 sentence aggregate, or null",
  "findings": [
    {
      "filePath": "src/main.py",
      "lineNumber": 42,
      "endLineNumber": 45,
      "severity": "error",
      "category": "bug",
      "message": "Description of the issue",
      "suggestion": "How to fix it",
      "subAgent": "critica-logic"
    }
  ]
}
```

## Repository Layout

```
content/                              # single source of truth (review prose + rules)
scripts/generate.sh                   # regenerates the per-engine files below
scripts/check-generated.sh            # CI drift check
.claude-plugin/marketplace.json       # Claude marketplace → ./plugins/critica-claude
.agents/plugins/marketplace.json      # Codex marketplace  → ./plugins/critica-codex
plugins/
  critica-claude/
    .claude-plugin/plugin.json
    agents/critica-*.md               # generated
    commands/review.md
    hooks/hooks.json + scripts/check-path.sh
  critica-codex/
    .codex-plugin/plugin.json
    skills/critica-review/SKILL.md     # generated
```

## Editing review content

The analysis-area prose and review rules live in `content/` and are the single source of truth.
After editing anything under `content/`, regenerate the derived files and commit them:

```bash
./scripts/generate.sh
git add content/ plugins/critica-claude/agents plugins/critica-codex/skills
```

`content/` feeds both:
- the Claude plugin sub-agents (`plugins/critica-claude/agents/critica-*.md`), used by `/critica:review`, and
- the Codex `critica-review` skill (`plugins/critica-codex/skills/critica-review/SKILL.md`).

CI (`drift-check`) fails if the generated files are out of sync.
