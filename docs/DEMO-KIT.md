# Demo Kit — show off the opencode-for-claude-code plugin

This is a script for demonstrating the plugin's value to a new user. Each demo
takes 2-5 minutes and highlights a different strength of the Conductor/Executor
pattern.

## Prerequisites

- opencode CLI installed and authenticated with a Go subscription
- Plugin installed and doctor passing (`/opencode:setup`)
- A repo with real code (any language)

---

## Demo 1: The Cost Lever — bulk read → small digest

**Show** how OpenCode Go ingests a large file and compresses it into a digest,
so Claude only pays for the reasoning, not the reading.

```
oc-delegate --tier flash --dir . --digest \
  "Read the ETL pipeline modules and summarize data flow, key configs, and risks."
```

**Narrate:** "opencode (a ~$0.14/1M-in model) read the whole codebase and returned
a compact digest. If Claude had read those files directly, it would have paid
$5-25/1M tokens for the same ingestion. The digest cost pennies; the reasoning is
what Claude does best."

---

## Demo 2: Conductor/Executor in action — diagnose

**Show** the `/opencode:diagnose` command as the showcase of the pattern.

Prerequisites: find or create a test failure / error log in your repo.

```
/opencode:diagnose <path-to-error-log>
```

**Narrate:** "opencode read the raw log, clustered the errors, extracted the
relevant stack traces, and returned a compact digest. I'm now reasoning from
that digest — I didn't spend tokens on wall-of-text ingestion."

---

## Demo 3: Fork-lift migration (fan-out)

**Show** the Orchestrator mode — decomposing a large task into parallel units.

Pick a mechanical refactor (rename, API migration, etc.) that touches many files.

```
oc-delegate --tier code --write --dir . --timeout 15m \
  "Migrate all usages of deprecated API v1 to v2 per SPEC.md."
```

**Narrate:** "I gave opencode a clear spec and a timeout. It worked autonomously
while I wasn't spending Claude tokens on file writes. I'll now review the diff."

---

## Demo 4: Background job (interactive session)

**Show** `/opencode:delegate` with background dispatch.

Narrate: "For longer tasks, I can background them and keep working."

```
ID=$(oc-job start --tier code --write --dir . --timeout 30m \
  "Refactor and add tests for the entire module per SPEC.md")
echo "Job ID: $ID"
```

Then show `/opencode:status $ID` and `/opencode:result $ID`.

---

## Demo 5: Cross-model review

**Show** how two different model families catch different bugs.

```
oc-delegate --tier pro --digest "Review this diff for bugs and security issues:"
```

Then show the combined human workflow: review opencode's findings, corroborate
against the actual code, keep real issues, discard false positives. "Agreement
between two independent model families is a stronger signal than either alone."

---

## Common talking points

- **"Is it actually cheaper?"** — The cost lever diagram: Claude reads 100K tokens
  of logs (at $5/1M = $0.50) vs. opencode reads 100K tokens (at $0.14/1M = $0.014)
  and returns 2K token digest. Claude reasons from 2K tokens = $0.01. Total: $0.024
  vs. $0.50 for Claude doing everything — and the real win is Claude context stays
  lean across turns, reducing `cache_read`.
- **"When NOT to delegate"** — Small, self-contained, or judgement-heavy tasks.
  Delegating a tiny task is slower AND more expensive.
- **"What about correctness?"** — Claude always verifies. See the verification gates
  in the skill. opencode's "green" is a claim, not evidence.
