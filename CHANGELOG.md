# Changelog

## 0.1.0 (2026-07-16)
- Initial release of the OpenCode for Claude Code plugin.
- Added `oc-delegate.sh` wrapper for timeout protection and structured exits.
- Introduced `opencode-delegate` subagent with Bash PreToolUse gating.
- Added 3-tier routing (`flash`, `code`, `pro`) mapped to OpenCode Go models.
- Added `/opencode:delegate`, `/opencode:setup`, and `/opencode:review` slash commands.
- Implemented `doctor.sh` health checks and startup hook.
