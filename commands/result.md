---
description: Fetch the result of a background OpenCode delegation job
argument-hint: "<job-id>"
---

Fetch the output of a finished background opencode job.

Run: `oc-job result $ARGUMENTS`

If the job is still running, report that and suggest trying again later.
Otherwise, print the stdout (the delegated work output) and the exit code.
