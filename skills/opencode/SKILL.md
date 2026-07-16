---
name: opencode
version: 0.2.0
description: Use OpenCode Go (curated open-source coding models via the headless `opencode run` CLI) as a cheap executor inside Claude Code. Claude is the conductor — requirements, architecture, the hard 20%, verification, review — and routes deterministic, high-volume work (scaffolding, well-specified implementation, test generation, migrations, first-pass review) to OpenCode Go models. Use when the user wants to "use opencode / OpenCode Go", "delegate to opencode", "implement with opencode", "scaffold / generate tests / migrate cheaply", "first-pass review on a cheap model", or "save Claude tokens on a big job". Claude always verifies OpenCode's output.
---

# OpenCode for Claude Code — hybrid SDLC

Run **OpenCode Go models** (GLM, Kimi, DeepSeek, Qwen, MiniMax — a $10/mo
subscription of curated OSS coding models) as cheap executors alongside Claude
Code. Keep judgement-heavy work on Claude (the frontier model); route
deterministic, high-volume work to OpenCode Go.

- **Claude = conductor** — requirements, architecture, the hard 20% (edge cases,
  integration, correctness), specs, tests-as-contract, final review.
- **OpenCode Go = executor** — a full headless coding agent (`opencode run`)
  that edits files, runs commands, and reads the repo's `AGENTS.md` natively.

## Two modes (pick per task)

- **Conductor (sync, inline):** shape something in real time; delegate a small,
  well-scoped chunk to opencode mid-flow (e.g. "generate these tests"), use the
  result immediately.
- **Orchestrator (async, multi-unit):** decompose a larger task into units,
  dispatch to opencode (often with `--dir`, agentic, in parallel), then review
  and integrate. Best for migrations, bulk implementation, test suites.

## Division of labor

| SDLC phase | Owner |
|---|---|
| Requirements, design, architecture | **Claude** |
| Implementation — complex / architecture-bearing (the 20%) | **Claude** |
| Implementation — scaffolding / well-specified | **opencode** (`code` tier) |
| Test & eval generation (Claude defines the contract) | **opencode** (`flash`/`code`) |
| First-pass code review → Claude final | **opencode** (`pro`) |
| Migrations / mechanical refactors | **opencode** executes, **Claude** directs |
| Web research / multi-source deep research | **opencode** fans out search/fetch · **Claude** verifies, synthesizes |
| Verification of anything that ships | **Claude** |

## How to call it

```bash
oc-delegate [options] "the task prompt"
```

Options: `--tier flash|code|pro` · `--dir <repo-root>` (single dir; opencode
reads `AGENTS.md` + real files there — always prefer this over pasting code) ·
`--write` (maps to opencode `--auto`; REQUIRED for any file edits in headless
mode — without it the delegation is read-only) · `--digest` (append a
digest-only output contract — use for any bulk read/analysis) ·
`--timeout 10m` · `-c`/`--continue` or `-s <session-id>` (hold multi-step state
on the cheap side) · `-m <provider/model>` (exact model from `opencode models`) ·
`--variant <effort>` · `--print-command` (dry run) · pipe a long prompt with a
trailing `-`.

**Two ways to delegate.** Call the wrapper directly, or — when file generation
should happen entirely on the cheap model with zero Claude tokens spent
writing — hand the unit to the **`opencode-delegate` subagent** (its only
file-acting tool is the wrapper; it returns a digest for you to verify).

**Background jobs** (interactive sessions only): fire a long delegation and keep
working. Use `oc-job start [options] "<task>"` to get a job ID, then
`/opencode:status`, `/opencode:result`, `/opencode:cancel` to manage. Headless
(`claude -p`) must delegate synchronously.

**Structured failures.** The wrapper exits `10` quota · `11` auth · `12`
timeout · `13` opencode-missing · `14` model-unavailable (besides `2` failed /
`3` empty) and prints an `OC_SIGNAL {...}` line on stderr — react to the code,
don't scrape prose.

**If Claude itself is running headless (`claude -p`):** delegate synchronously;
never background a delegation expecting a later turn.

## Tier routing & quota discipline (Go-specific)

OpenCode Go limits are **dollar-based**: ~$12 per 5h window, ~$30/week,
~$60/month. Model prices differ hugely, so tier choice IS quota management:

- `flash` = `opencode-go/deepseek-v4-flash` — default. Cheap (~158k req/mo
  headroom): bulk reads, test generation, simple scaffolds, digests.
- `code` = `opencode-go/kimi-k2.7-code` — implementation against a clear spec.
- `pro` = `opencode-go/glm-5.2` — strongest but scarce (~4.3k req/mo): hard
  reasoning, first-pass reviews, retry-after-failure. **One runaway `pro`
  agentic loop can exhaust the 5h window** — pass a tight spec and `--timeout`.

Escalation path when output is wrong: sharpen the spec → retry on `pro` → do it
yourself. Tiers are remappable via plugin options (`tier_flash` / `tier_code` /
`tier_pro`) as OpenCode rotates its model lineup.

## Shared harness: one AGENTS.md for both AIs

opencode natively reads `AGENTS.md` from the workspace. Keep a single shared
`AGENTS.md` at the repo root so Claude and OpenCode operate under the same
rules. **When delegating any repo work, always pass `--dir <repo-root>`** so
opencode loads AGENTS.md and the real code instead of pasted context.

## Verification gates (non-negotiable)

Claude owns correctness. For anything that ships:

1. **Define the contract first** — Claude writes/owns the tests; they tell the
   executor what "correct" means more precisely than prose.
2. **Actually run it** — reading the diff is necessary but not sufficient. Run
   the tests, launch the app, hit the real endpoints. If you cannot run it, say
   so explicitly — do not mark the gate passed.
3. **Verify files actually changed** on write tasks (`git status` / `git diff`)
   — a confident "done" with no writes is a known cheap-model failure mode.
4. **Review every shipping line** — check imports are real packages
   (hallucinated deps), error handling, edge cases.
5. **Never trust the executor's self-reported green** — re-run the gate yourself
   in a clean state. A cheap model may stub or patch its way to a pass.

## Safety for write tasks

- `--write` grants file edits + command auto-approval. Run write tasks on a
  **dedicated git branch or worktree**; review the diff before merging; never
  auto-merge.
- Read-only work (analysis, review, search) needs no `--write` and is low-risk.

## Cost discipline — where the savings actually come from

Delegation does not save money by itself. Measured reality: on a small task the
hybrid cost *more* than Claude-only, because the dominant cost was Claude's own
`cache_read` — re-reading a large, growing context across many turns.

Apply these as hard rules:

1. **Delegate above the break-even, not below.** Bulk/parallel/repetitive (mass
   migration, exhaustive tests, fan-out research, long-context reads that return a
   small digest) = delegate. Small, self-contained, or judgement-heavy = do it
   yourself. Delegating a tiny task is a *net loss*.
2. **Keep Claude's context lean (the biggest lever).** Do **not** pull the files
   opencode already handled back into Claude's context, and do **not** paste
   opencode's raw bulky output into the thread. Ingest a **digest** (`--digest`
   appends the contract trailer). This collapses the per-turn `cache_read` that
   made the hybrid expensive.
3. **Make opencode return a digest, not a dump.** End every delegation prompt
   with `"...End with ===DIGEST=== listing: files changed, key decisions, and a
   1-paragraph context for next step. Put bulky detail ONLY in files."`
4. **Batch, don't chatter.** One large, fully-specified delegation beats many
   small round-trips (each round-trip re-reads context = `cache_read` tax).
5. **Review the diff, not the whole tree.** `git diff` is compact; reading every
   file is not.
6. **Hold state on the cheap side** — reuse a session (`-c` / `-s <id>`) so the
   working context lives in OpenCode, and pass deltas instead of re-supplying
   everything.
7. **Don't fight the prompt-cache TTL on small tasks.** The 5-min cache expires
   while you wait on a long delegation, so the next turn pays `cache_create`
   (1.25x) instead of `cache_read` (0.1x). Do NOT manufacture work to stay warm —
   that backfires (warming turns generate expensive frontier output). The only fix
   is **scale**: make each delegation big enough that the displaced Claude output
   dwarfs the one-time re-cache cost.

## Recipes

```bash
ROOT=oc-delegate

# Scaffold from a spec Claude wrote (on a branch)
"$ROOT" --tier code --write --dir ./app \
  "Scaffold per ARCHITECTURE.md: dirs, configs, stub modules. Follow AGENTS.md."

# Generate tests for a contract Claude defined
"$ROOT" --tier flash --write --dir ./app \
  "Write unit + edge-case tests for src/payments.py covering SPEC.md."

# Implement-until-tests-pass (isolate on a branch; Claude re-runs the gate after)
"$ROOT" --tier code --write --dir ./app --timeout 20m \
  "Implement feature X per AGENTS.md and make 'pytest -q' pass. Iterate until green."

# First-pass review (Claude does the final pass)
{ echo "Review this diff for bugs/security/perf, be skeptical. List file:line findings."; git diff; } \
  | "$ROOT" --tier pro --digest -

# Migration / mechanical refactor
"$ROOT" --tier code --write --dir ./svc --timeout 20m \
  "Migrate all callers from APIv1 to APIv2 per MIGRATION.md. List every file changed."

# Bulk read → digest (keeps Claude's context lean)
"$ROOT" --tier flash --dir ./big-repo --digest \
  "Read the ETL pipeline modules and summarize data flow, key configs, and risks."

# Background job (interactive session only; collect with /opencode:result)
oc-job start --tier pro --write --dir ./svc --timeout 30m \
  "Migrate all callers from APIv1 to APIv2 per MIGRATION.md. List every file changed."

# Web research → Claude re-checks (needs OPENCODE_ENABLE_EXA for websearch)
"$ROOT" --tier flash --write "Use web search for <X>. Return 5-8 bullet findings with URLs."
```

## Prerequisites & limits

- `opencode` CLI installed (`curl -fsSL https://opencode.ai/install | bash`) and
  authenticated with an OpenCode Go subscription (`opencode models` must list
  `opencode-go/*`). Run `/opencode:setup` to check.
- `opencode run` takes a **single** `--dir`; no built-in timeout (the wrapper
  adds one); `--auto` is the only headless permission mode (all-or-nothing).
- OpenCode Go quotas are shared across everything using the subscription — a
  heavy delegation day eats the same budget as your interactive TUI use.
