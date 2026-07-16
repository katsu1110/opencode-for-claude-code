---
description: Delegate a subtask to an OpenCode Go model via oc-delegate
argument-hint: "[--tier flash|code|pro] <task>"
---

Delegate the following task to OpenCode Go via the plugin wrapper, following the
`opencode` skill's **Cost discipline** and **Verification gates**.

Task: $ARGUMENTS

Do this:
1. Pick a tier (`flash` default; `code` for implementation; `pro` for hard reasoning).
   If the task needs the repo, add `--dir <repo-root>` so opencode reads the real
   files (don't paste them into context).
   **If the task WRITES files**, grant write permission:
   - Use `--write` (maps to opencode's `--auto` — auto-approves permissions).
   - Run write tasks on a dedicated branch, and **verify files actually changed**
     (`git diff --stat` after).
2. Run **synchronously** (you may be headless — do not background-and-wait):
   `oc-delegate --tier <tier> [--dir .] [--write] [--digest] "<task>"`
3. Ingest only the **result/digest** — do NOT re-read the files opencode already
   handled (keeps your context lean). If the wrapper prints a *"raw dump"* note on
   stderr, do NOT ingest the raw output — re-run with `--digest`.
4. **Verify**: actually run/check the output; never trust a self-reported "done".

Remember the break-even: only delegate if the offloaded volume clearly exceeds the
spec + round-trip + verification overhead. Tiny tasks are cheaper to just do yourself.

**Long task, interactive session?** Background it:
`ID=$(oc-job start --tier pro --dir . "<task>")`
then check with `/opencode:status` and collect with `/opencode:result <id>`.
(Don't do this when headless `claude -p` — delegate synchronously there.)
