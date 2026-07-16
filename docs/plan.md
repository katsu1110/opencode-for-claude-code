# OpenCode for Claude Code — Implementation Plan

Derived from a gap analysis against [antigravity-for-claude-code](https://github.com/yuting0624/antigravity-for-claude-code).
OpenCode Go docs consulted at https://opencode.ai/docs/go/ for pricing and capability assessment.

## Phase 1 — Foundation (CI + bin/ shims + pricing)

| Task | Detail |
|------|--------|
| Add `.github/workflows/ci.yml` | shellcheck + JSON validation + offline tests, ported from antigravity |
| Add `CONTRIBUTING.md` | Dev setup, conventions, PR checklist |
| Add `prices.json` | Real OpenCode Go rates per model (input/output/cached-read/write) from docs |
| Add `bin/` shims: `oc-job`, `oc-doctor`, `oc-cost-compare` | Forward to `scripts/` like `bin/oc-delegate` does |
| Update `bin/oc-delegate` | Make it consistent with others |

## Phase 2 — Scripts (background jobs + cost tooling)

| Task | Detail |
|------|--------|
| Write `scripts/oc-job.sh` | Port from `agy-job.sh` — background job start/list/status/result/cancel using `oc-delegate` |
| Write `scripts/oc-cost-compare.sh` | Port from `agy-cost-compare.sh` — run a task, estimate Claude vs OpenCode cost using `prices.json` |
| Write `scripts/measure-session.py` | Port from antigravity — reads Claude session JSONL, prints token+USD breakdown. Adapt for OpenCode Go prices |
| **Skip `scripts/oc-trace.sh`** | No documented transcript.jsonl equivalent in OpenCode docs. Revisit if discovered empirically. |
| Harden `scripts/oc-delegate.sh` | Add WSL slow-mount guard, write-task warning, exit code 14 (`MODEL_UNAVAILABLE`), `--mode accept-edits\|plan` passthrough |

## Phase 3 — Hooks (policy injection + delegation nudge)

| Task | Detail |
|------|--------|
| Add `hooks/policy-context.json` | Cost-aware routing policy text for OpenCode (port from antigravity, adapt model names/limits) |
| Add `hooks/inject-policy.sh` | SessionStart + compact hook that reads `policy-context.json`, toggleable via `coding_policy` option |
| Add `hooks/nudge-delegation.sh` | UserPromptSubmit hook: conservative heuristic for bulk-work prompts (EN + JA), toggleable via `delegation_nudge` option |
| Update `hooks/hooks.json` | Register all 3 categories: SessionStart (check + policy), compact (policy), UserPromptSubmit (nudge) |
| Update `hooks/check-oc.sh` | Add `opencode --version` check and `timeout` guard |
| Update `hooks/validate-delegate-bash.sh` | Allow `oc-job` and `oc-cost-compare` names |

## Phase 4 — Commands (expand + new slash commands)

| Task | Detail |
|------|--------|
| Expand `commands/delegate.md` | Add `argument-hint`, write-mode guidance, digest guidance, break-even reminder, background-job instructions |
| Expand `commands/review.md` | Add `--adversarial` flag, detailed reconciliation instructions |
| Expand `commands/setup.md` | Use bare `oc-doctor` bin name instead of `$CLAUDE_PLUGIN_ROOT` path |
| Add `commands/research.md` | Claude-orchestrated deep research using `opencode run` + `webfetch`/`websearch` tools. Adapt from antigravity's multi-source recipe but with Exa instead of Google |
| Add `commands/status.md` | Background-job status (`oc-job status <id>`) |
| Add `commands/result.md` | Background-job result collector |
| Add `commands/cancel.md` | Background-job cancellation |

## Phase 5 — SKILL.md + agent hardening

| Task | Detail |
|------|--------|
| Update `skills/opencode/SKILL.md` | Add `version:` frontmatter synced with `plugin.json`. Add the "proactive" wording. Add deep-research recipe. Add richer cost-discipline prose (cache-TTL trap, asymmetric effort, etc.) |
| Update `agents/opencode-delegate.md` | Add "PROACTIVELY" keyword + "the break-even judgment is yours" counterweight. Add `oc-job` reference |

## Phase 6 — Doctor + plugin options

| Task | Detail |
|------|--------|
| Expand `scripts/doctor.sh` | Check bin/ shims, check `opencode models` for tier models (with timeout guard), report plugin version, WSL warning |
| Update `plugin.json` | Add `coding_policy`, `delegation_nudge` options. Bump version to `0.2.0` |

## Phase 7 — Tests

| Task | Detail |
|------|--------|
| Expand `tests/run-tests.sh` | Add tests for: bin/ shims, `inject-policy.sh`, `nudge-delegation.sh`, `oc-job.sh`, `oc-cost-compare.sh`, `measure-session.py`, plugin contract validation |

## Phase 8 — Docs

| Task | Detail |
|------|--------|
| Add `docs/TROUBLESHOOTING.md` | Symptom-first fixes for common issues |
| Add `docs/AB-RESULTS.md` | Placeholder for measured comparison data (fill in after benchmarks) |
| Expand `README.md` | CI badge, command table, known limits, local dev instructions, documented pricing |

## What stays NOT ported

| Antigravity feature | Reason |
|---------------------|--------|
| `cloud-debug.sh` / `/cloud-run-debug` | GCP-specific. No equivalent in OpenCode. |
| `agy-trace.sh` | No subagent transcript.jsonl documented in OpenCode docs. |
| `flash-lo` tier | Only 3 tiers needed (flash/code/pro). |
| Vertex AI Search tools | Gemini-specific MCP. |
| Google web search | Replace with Exa web search via `OPENCODE_ENABLE_EXA=1`. |

## Pricing reference (OpenCode Go, per 1M tokens, USD)

From https://opencode.ai/docs/go/ — Jul 2026:

| Model | Input | Output | Cached Read | Cached Write |
|-------|-------|--------|-------------|-------------|
| GLM-5.2 | $1.40 | $4.40 | $0.26 | — |
| GLM-5.1 | $1.40 | $4.40 | $0.26 | — |
| Kimi K2.7 Code | $0.95 | $4.00 | $0.19 | — |
| Kimi K2.6 | $0.95 | $4.00 | $0.16 | — |
| MiMo V2.5 | $0.14 | $0.28 | $0.0028 | — |
| MiMo V2.5 Pro | $1.74 | $3.48 | $0.0145 | — |
| MiniMax M3 | $0.30 | $1.20 | $0.06 | — |
| MiniMax M2.7 | $0.30 | $1.20 | $0.06 | $0.375 |
| MiniMax M2.5 | $0.30 | $1.20 | $0.06 | $0.375 |
| Qwen3.7 Max | $2.50 | $7.50 | $0.50 | $3.125 |
| Qwen3.7 Plus | $0.40 | $1.60 | $0.04 | $0.50 |
| Qwen3.6 Plus | $0.50 | $3.00 | $0.05 | $0.625 |
| DeepSeek V4 Pro | $1.74 | $3.48 | $0.0145 | — |
| DeepSeek V4 Flash | $0.14 | $0.28 | $0.0028 | — |
