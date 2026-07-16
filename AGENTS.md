# AGENTS.md — opencode-for-claude-code

Rules for any AI agent working in this repository.

## What this repo is

A Claude Code plugin that lets Claude delegate well-scoped work to OpenCode Go
models via the headless `opencode run` CLI. Claude is the conductor (planning,
the hard 20%, verification); OpenCode Go models are the cheap executors.
It is deliberately modeled on the `antigravity-for-claude-code` plugin.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest + userConfig options.
- `bin/oc-delegate` — PATH shim; forwards to `scripts/oc-delegate.sh`.
- `scripts/oc-delegate.sh` — THE core wrapper. Its header comment is the CLI
  contract (options, exit codes, OC_SIGNAL). Keep header and behavior in sync.
- `scripts/doctor.sh` — install/auth/model checks.
- `skills/opencode/SKILL.md` — routing policy loaded by Claude on demand.
- `agents/opencode-delegate.md` — subagent whose only file-acting tool is the wrapper.
- `commands/*.md` — /opencode:delegate, /opencode:setup, /opencode:review.
- `hooks/` — SessionStart check (`check-oc.sh`, silent when healthy) and the
  subagent Bash gate (`validate-delegate-bash.sh`).
- `tests/run-tests.sh` — OFFLINE tests only (no live API calls, no network).

## Hard rules

- Bash + Python only, `set -euo pipefail`, POSIX-leaning; dependencies limited to
  bash + coreutils + grep/sed + python3 for JSON parsing/token accounting.
  Must run on macOS (no `timeout(1)`, BSD sed) and Linux.
- Exit-code contract of `oc-delegate.sh` is frozen:
  `0 ok | 1 usage | 2 run failed | 3 empty | 10 quota | 11 auth | 12 timeout | 13 opencode missing`.
- Classifiable failures MUST print a single-line `OC_SIGNAL {json}` to stderr.
- Success MUST mean non-empty stdout.
- Tests must pass without an `opencode` login and without network: use
  `--print-command` dry runs and PATH stubbing to test behavior.
- All scripts executable (`chmod +x`).
- Model tier defaults: flash=opencode-go/deepseek-v4-flash,
  code=opencode-go/kimi-k2.7-code, pro=opencode-go/glm-5.2 — overridable via
  `CLAUDE_PLUGIN_OPTION_*` env vars; never hardcode elsewhere.
- Docs tell the truth about limits: OpenCode Go limits are dollar-based
  ($12/5h, $30/wk, $60/mo); never promise flat cost-savings ratios.
