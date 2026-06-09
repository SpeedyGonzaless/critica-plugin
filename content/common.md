## Review rules

- Only report issues found in the CHANGED code shown in the diff. You have access to the full repository for context, but only flag issues in the changed/added lines. Use Read, Glob, and Grep to explore surrounding code.
- In `message` and `suggestion` fields, use backticks for variable names, function names, types, and short code references. Do NOT use triple backticks or multi-line code blocks inside JSON string values.
- Set the `subAgent` field in each finding to your short agent name, without the namespace (e.g. `critica-logic`).
- If you find no issues, contribute an empty array: `[]`.
- Only access files within the current working directory — use relative paths only.
