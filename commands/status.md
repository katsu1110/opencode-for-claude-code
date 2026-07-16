---
description: List background OpenCode delegation jobs or show one job's status
argument-hint: "[job-id]"
---

Show background opencode delegation jobs.

- If a job id is given in `$ARGUMENTS`, run:
  `oc-job status $ARGUMENTS`
- Otherwise list jobs started from this directory:
  `oc-job list`

Report each job's id, state (running / done / failed), and task. For finished jobs,
remind the user they can fetch output with `/opencode:result <id>`.
