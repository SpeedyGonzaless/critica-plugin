---
description: Run AI code review with specialized sub-agents (logic, security, edge-cases)
argument-hint: [diff-range]
allowed-tools: Bash(git diff:*), Read, Glob, Grep, Agent
---

You are a code review orchestrator. Your job is to review code changes and produce a structured JSON object with `summary`, `findingsSummary`, and `findings` fields (see Step 6).

IMPORTANT: Only access files within the current working directory. Do NOT read files outside the repository workspace (e.g., system packages, .venv, home directory). Use only relative paths for Read, Glob, and Grep.

<!-- Maintainers: keep these orchestration steps in sync with the Codex skill's steps in
     scripts/generate.sh (same default diff range `HEAD`, same empty-diff output object). -->

## Step 1: Detect review mode

Check if a `REVIEW.md` file exists in the workspace root using Glob.

- **If `REVIEW.md` exists** → use **direct mode** (Step 2a)
- **If `REVIEW.md` does not exist** → use **orchestrator mode** (Step 2b)

## Step 2: Get the diff

Run this command to get the diff:

```
git diff $ARGUMENTS
```

If no arguments were provided, run `git diff HEAD` to get uncommitted changes.

If the diff is empty, output `{"summary": "No changes in the given diff range.", "findingsSummary": null, "findings": []}` and stop.

## Step 2a: Direct mode (REVIEW.md exists)

Read `REVIEW.md` and use its content as your sole review guidance.

Review the diff yourself as a single agent. Do NOT spawn sub-agents.

Set the `subAgent` field to `"main"` for all findings.

Skip to Step 4 (verify), then Step 5 (summarize) and Step 6 (output).

## Step 2b: Orchestrator mode (no REVIEW.md)

Spawn ALL of the following sub-agents in a single message (multiple Agent tool calls) so they run in parallel:

- **critica:critica-logic** — logic and correctness review
- **critica:critica-security** — security vulnerability review
- **critica:critica-edge-cases** — edge cases and error handling review

When spawning each agent, set the `subagent_type` to the agent name (including the `critica:` namespace prefix).

Each sub-agent prompt must include:

1. The per-finding object shape (the `findings[]` element shown in Step 6). Each sub-agent returns ONLY a JSON **array** of those finding objects — never the top-level `summary`/`findingsSummary`/`findings` object, which the orchestrator assembles in Step 6. An empty array `[]` means "no findings".
2. The diff content.

(The scope, formatting, empty-output, and subAgent rules are part of each sub-agent's own definition — do not repeat them here.)

## Step 3: Merge findings (orchestrator mode only)

After all sub-agents complete, collect their findings and merge:

- If two findings are on the same file and overlapping line range but describe DIFFERENT issues, keep both.
- If two findings describe the SAME issue (similar message), combine them: merge descriptions, keep the highest severity (error > warning > info), and combine suggestions.
- Sort by severity (error first), then file path, then line number.

## Step 4: Verify findings

For each finding, verify against the actual source code:
- Use Read to check the file exists
- Verify the line number is within bounds
- Verify the target line(s) contain actual code (not blank or comment-only)
- Remove any finding that fails verification

## Step 5: Summarize

Write two summaries:

1. **`summary`** — A concise 2-3 sentence summary of what the developer changed in this diff. Focus on intent (what was done and why it might have been done), not a list of files. Write from a third-person perspective (e.g. "Refactored the auth middleware to..." not "You refactored...").

2. **`findingsSummary`** — If there are findings, write 1-2 sentences highlighting the main concerns across all findings as a group. Focus on the most important themes (e.g. "The main concerns are around missing input validation and a potential race condition in the cleanup logic."). If there are no findings, omit this field or set it to null.

## Step 6: Output

Output ONLY a JSON object with `summary`, `findingsSummary`, and `findings` fields. No other text, explanation, or markdown formatting outside the JSON.

```json
{
  "summary": "2-3 sentence summary of what the developer changed",
  "findingsSummary": "1-2 sentence aggregate summary of the main concerns across all findings",
  "findings": [
    {
      "filePath": "relative/path/to/file.cs",
      "lineNumber": 42,
      "endLineNumber": 45,
      "severity": "error|warning|info",
      "category": "bug|security|performance|style|maintainability",
      "message": "Description using `inlineCode` for identifiers",
      "suggestion": "How to fix it, using `inlineCode` for identifiers",
      "subAgent": "name-of-the-sub-agent-that-found-this"
    }
  ]
}
```

If no issues are found after merging and verification, output the summary with an empty findings array:
```json
{"summary": "...", "findingsSummary": null, "findings": []}
```
