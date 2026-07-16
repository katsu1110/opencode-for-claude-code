# Changelog

## 0.2.0 (2026-07-16)
- **`prices.json`**: Real OpenCode Go per-1M-token rates for all 13 models.
- **`bin/` entrypoints**: `oc-job`, `oc-doctor`, `oc-cost-compare` shims (fixes `$CLAUDE_PLUGIN_ROOT` failures on marketplace installs).
- **Background jobs**: `scripts/oc-job.sh` with `start|list|status|result|cancel`. Slash commands `/opencode:status`, `/opencode:result`, `/opencode:cancel`.
- **Cost comparison**: `scripts/oc-cost-compare.sh` — run a task on opencode, compare Claude vs Go costs.
- **Session accounting**: `scripts/measure-session.py` — token and USD breakdown from Claude session JSONL.
- **Wrapper hardening**: WSL slow-mount guard, write-task warning, exit code 14 (`MODEL_UNAVAILABLE`), `--mode accept-edits` passthrough.
- **Policy injection**: `hooks/inject-policy.sh` + `hooks/policy-context.json` — SessionStart cost-aware routing policy (toggleable via `coding_policy` option).
- **Delegation nudge**: `hooks/nudge-delegation.sh` — UserPromptSubmit heuristic for bulk-looking prompts (toggleable via `delegation_nudge` option).
- **`hooks/check-oc.sh`**: Now checks `opencode --version` and distinguishes absent from broken.
- **`hooks/validate-delegate-bash.sh`**: Now allows `oc-job` and `oc-cost-compare` names.
- **`plugin.json`**: Added `coding_policy` and `delegation_nudge` user options.
- **`doctor.sh`**: Now checks bin/ shims, model presence, WSL workspace path, and plugin version.
- **New commands**: `/opencode:research` (deep research), `/opencode:status`, `/opencode:result`, `/opencode:cancel`.
- **`SKILL.md`**: Added `version:` frontmatter, proactive subagent wording, deep-research recipe, richer cost-discipline prose.
- **`opencode-delegate.md`**: PROACTIVELY keyword added; now references `oc-job` and `oc-cost-compare`.
- **Tests**: Expanded from 18 to 44 tests covering shims, hooks, jobs, cost-compare, measure-session, and plugin contract.
- **CI**: `.github/workflows/ci.yml` — shellcheck + JSON validation + offline tests.
- **`CONTRIBUTING.md`**: Dev setup, conventions, PR checklist.
- **`docs/`**: Added `plan.md` and `TROUBLESHOOTING.md`.

## 0.1.0 (2026-07-16)
- Initial release of the OpenCode for Claude Code plugin.
- Added `oc-delegate.sh` wrapper for timeout protection and structured exits.
- Introduced `opencode-delegate` subagent with Bash PreToolUse gating.
- Added 3-tier routing (`flash`, `code`, `pro`) mapped to OpenCode Go models.
- Added `/opencode:delegate`, `/opencode:setup`, and `/opencode:review` slash commands.
- Implemented `doctor.sh` health checks and startup hook.
