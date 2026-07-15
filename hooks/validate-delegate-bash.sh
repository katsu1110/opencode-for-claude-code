#!/usr/bin/env bash
#
# PreToolUse(Bash) gate for the `opencode-delegate` subagent.
# allow a Bash call ONLY when it invokes the plugin's delegation wrapper
# (oc-delegate / oc-delegate.sh); block everything else with exit code 2.
#
set -uo pipefail

input="$(cat)"

if command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c \
    'import json,sys
try:
    print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception:
    pass' 2>/dev/null || true)"
else
  cmd="$input"
fi

# Allow only when oc-delegate is the command actually being executed:
# either the first word, or the target of a simple prompt-producing pipeline
# (echo/printf/cat | oc-delegate -). A bare substring match would let
# arbitrary commands through with "oc-delegate" in a comment or argument.
first_ok='^[[:space:]]*([[:alnum:]_/.~-]*/)?oc-delegate(\.sh)?([[:space:]]|$)'
pipe_ok='^[[:space:]]*(echo|printf|cat)[^;&`]*\|[[:space:]]*([[:alnum:]_/.~-]*/)?oc-delegate(\.sh)?([[:space:]]|$)'
if printf '%s' "$cmd" | grep -qE "$first_ok" || printf '%s' "$cmd" | grep -qE "$pipe_ok"; then
  exit 0
fi

echo "[opencode-delegate] blocked: this subagent may only run oc-delegate / oc-delegate.sh via Bash. Delegate file work to opencode; verification is the caller's job." >&2
exit 2
