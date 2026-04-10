# Critica — AI Code Review Plugin for Claude Code

A Claude Code plugin that runs AI-powered code reviews with specialized sub-agents for logic, security, and edge cases.

## Prerequisites

- [jq](https://jqlang.github.io/jq/) — used by the path-checking hook to parse JSON

## Installation

From inside Claude Code:

```shell
# Add the marketplace
/plugin marketplace add mazurov/critica-plugin

# Install the plugin
/plugin install critica@critica
```

Or from the CLI:

```bash
claude plugin marketplace add mazurov/critica-plugin
claude plugin install critica@critica
```

## Usage

```bash
# Review uncommitted changes
/critica

# Review last commit
/critica HEAD~1

# Review specific range
/critica main..HEAD

# Review staged changes
/critica --cached
```

## How It Works

The `/critica` command:

1. **Detects mode** — if `REVIEW.md` exists in the repo root, uses it as custom review guidance (direct mode). Otherwise, uses specialized sub-agents (orchestrator mode).

2. **Gets the diff** — runs `git diff` with the provided arguments.

3. **Runs sub-agents in parallel** (orchestrator mode):
   - `critica-logic` — logical errors, bugs, correctness issues
   - `critica-security` — security vulnerabilities (OWASP, injection, auth)
   - `critica-edge-cases` — edge cases, error handling, boundary conditions

4. **Merges and verifies** findings against actual source code.

5. **Outputs** a JSON array of findings.

## Custom Review Instructions

Create a `REVIEW.md` in your repository root to provide custom review guidance. When present, the plugin uses your instructions instead of the default sub-agents.

## Sub-Agents

Each sub-agent has restricted tools (`Read`, `Glob`, `Grep` only) and focused instructions:

| Agent | Focus |
|-------|-------|
| `critica-logic` | Logical errors, null refs, off-by-one, race conditions |
| `critica-security` | Injection, auth flaws, data exposure, OWASP Top 10 |
| `critica-edge-cases` | Boundary conditions, error handling, resource leaks |

## Output Format

```json
[
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
```
