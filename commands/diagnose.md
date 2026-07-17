---
description: Diagnose errors, logs, or CI failures — OpenCode Go does the bulk reading/digesting; Claude reasons about root cause and proposes fixes
argument-hint: "[--apply] <what to diagnose — file path, CI log, or error description>"
---

Diagnose a failure using OpenCode Go as the bulk reader + digester and you (Claude)
as the root-cause reasoner. This demonstrates the **Conductor/Executor pattern** in
its most effective form: a cheap model ingests a large dump and compresses it to a
small digest; the expensive model reasons from the digest, not the raw dump.

Target/flags: $ARGUMENTS

Do this:

1. **If the target is a file path** (error log, test output, stack trace file), use
   `oc-diagnose` with `--dir <repo>` to have opencode read and digest it:
   ```
   oc-diagnose [--tier flash] [--dir .] <path>
   ```
2. **If the target is a CI failure URL or error description**, delegate to opencode
   via `oc-delegate --write` to fetch the page/log, then return a structured digest.
3. **If `--apply` is set**, create a dedicated worktree or branch for any fixes;
   the default is read-only analysis.

opencode's diagnostic digest should include:
- Error clusters — the top N most common error patterns
- Representative stack traces or log excerpts (compact)
- Time/count distribution if timestamps are available
- Root cause candidates (be skeptical — these are hypotheses, not verdicts)

Then YOU (Claude) do:
4. **Reason** from the digest: cross-reference against the actual code, check for
   known failure modes, validate root cause candidates against the evidence.
5. **Report** findings from most severe to least, with file:line references to
   the actual code.
6. **If `--apply`**, implement the fix in the dedicated worktree, then present
   the diff for review.

Remember the cost lever: opencode ingests the raw dump (many tokens, cheap model);
you see only the digest (few tokens, expensive model). Do NOT re-read the raw files
opencode already processed — that erases the savings.
