#!/usr/bin/env bash
#
# PreToolUse(Bash) gate for the `opencode-delegate` subagent.
# Allow a Bash call ONLY when it invokes the plugin's delegation wrapper
# (oc-delegate / oc-delegate.sh); block everything else with exit code 2.
#
# Validation is a whole-string match, not a substring scan: quoted prompt text
# is stripped first, then the remainder may contain nothing but the wrapper
# invocation and plain option words — no `;`, `&`, newlines, redirections, or
# command/process substitution anywhere (backticks and `$(` are rejected even
# inside double quotes, where they would still execute).
#
# Requires python3 (correct JSON parse + quote stripping). If python3 is
# unavailable the gate FAILS CLOSED and says so.
#
set -uo pipefail

input="$(cat)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[opencode-delegate] blocked: this gate needs python3 to validate commands safely, and python3 was not found. Install python3 to use the opencode-delegate subagent." >&2
  exit 2
fi

if printf '%s' "$input" | python3 -c '
import json, re, sys

try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "")
except Exception:
    sys.exit(1)

# 1. Drop single-quoted spans (bash performs no expansion inside them).
s = re.sub(r"\x27[^\x27]*\x27", "", cmd)
# 2. Backticks / $( execute even inside double quotes — reject outright.
if re.search(r"`|\$\(", s):
    sys.exit(1)
# 3. Drop double-quoted spans (prompt text), honoring escaped characters.
s = re.sub(r"\"(\\\\.|[^\"\\\\])*\"", "", s)

# 4. Whole-remainder match: wrapper + option words only. The character
# classes exclude newlines and all shell metacharacters, so nothing can be
# chained, redirected, or smuggled on another line.
DELEG = r"[\w./~+:@-]*oc-delegate(\.sh)?"
WORDS = r"[ \t\w./~+:@=,%-]*"
form1 = re.fullmatch(r"[ \t]*" + DELEG + WORDS, s)
form2 = re.fullmatch(r"[ \t]*(echo|printf|cat)" + WORDS + r"\|[ \t]*" + DELEG + WORDS, s)
sys.exit(0 if (form1 or form2) else 1)
'; then
  exit 0
fi

echo "[opencode-delegate] blocked: this subagent may only run oc-delegate / oc-delegate.sh via Bash (bare name or unquoted path; single command, no chaining/substitution; pipe prompts with echo/printf/cat | oc-delegate -). Delegate file work to opencode; verification is the caller's job." >&2
exit 2
