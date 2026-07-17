#!/usr/bin/env bash
#
# diagnose.sh — diagnose errors/logs/failures using opencode as the bulk reader
# and digester. Part of the "OpenCode for Claude Code" plugin.
#
# This is the engine behind `/opencode:diagnose`. It takes a target (file path or
# error description), delegates bulk reading + digesting to opencode, and returns
# a structured diagnostic digest (error clusters, stack traces, root cause candidates).
#
# Usage:
#   diagnose.sh [options] <target>
#   echo "error description or log text" | diagnose.sh [options] -
#
# Options:
#   -t, --tier <flash|code|pro>   Model tier (default: flash)
#   -d, --dir <path>              Workspace directory (so opencode reads real files)
#       --timeout <dur>           Wall-clock timeout, e.g. 10m, 300s (default: 10m)
#       --apply                   Attempt to apply fixes (uses --write; run on a branch)
#       --print-command           Print the resolved delegate command and exit (dry run)
#   -h, --help                    Show this help
#
# Notes:
#   Reads from stdin when the last argument is '-'; otherwise the last argument is
#   the target (file path or error description). If the target is an existing file,
#   it is read and used as context for the diagnosis.
#
# End of help.
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DELEGATE="${OC_DELEGATE:-$HERE/oc-delegate.sh}"
TIER="${CLAUDE_PLUGIN_OPTION_DEFAULT_TIER:-flash}"
TIMEOUT="${CLAUDE_PLUGIN_OPTION_TIMEOUT:-10m}"
RUN_DIR=""
APPLY=0
PRINT_CMD=0
TARGET=""

die() { echo "diagnose: $*" >&2; exit 1; }
usage() { sed -n '/^# Usage:/,/^# End of help./p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0; }

# $1 = remaining argc ($#). Fail with a friendly message if an option has no value.
need() { [ "$1" -ge 2 ] || die "option '$2' needs a value"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tier)   need $# "$1"; TIER="$2"; shift 2 ;;
    -d|--dir)    need $# "$1"; RUN_DIR="$2"; shift 2 ;;
    --timeout)   need $# "$1"; TIMEOUT="$2"; shift 2 ;;
    --apply)     APPLY=1; shift ;;
    --print-command) PRINT_CMD=1; shift ;;
    -h|--help)   usage ;;
    -)           TARGET="-"; shift ;;
    --)          shift; break ;;
    -*)          die "unknown option '$1' (see --help)" ;;
    *)           [ -n "$TARGET" ] && die "target given twice"; TARGET="$1"; shift ;;
  esac
done

[ -n "$TARGET" ] || die "no target given (pass a file path or error description)"

CONTEXT=""
if [ -f "$TARGET" ]; then
  CONTEXT="$(cat "$TARGET" 2>/dev/null || true)"
  [ -n "$CONTEXT" ] || die "cannot read file: $TARGET"
  TARGET_LABEL="$TARGET"
elif [ "$TARGET" = "-" ]; then
  CONTEXT="$(cat)"
  TARGET_LABEL="(stdin)"
else
  CONTEXT="$TARGET"
  TARGET_LABEL="$TARGET"
fi

# Build a structured diagnostic prompt for opencode
PROMPT="You are a diagnostic engine. Analyze the following error context and produce a STRUCTURED DIAGNOSTIC DIGEST with these sections:

1. ERROR CLUSTERS — Group errors by pattern; list the top N most frequent with a count estimate.
2. REPRESENTATIVE TRACES — For the top 2-3 clusters, show a compact representative stack trace or log excerpt (trim redundant frames with '...').
3. TIME DISTRIBUTION — If timestamps are present, note any time-based pattern (bursts, frequency, recent uptick).
4. ROOT CAUSE CANDIDATES — List 1-3 hypotheses. For each, state: (a) what evidence supports it, (b) what contradicts it, (c) how to confirm or rule it out.
5. KEY FILES — Which source files are likely involved (file paths only, no code).

Be concise but precise. The reader (a senior engineer) needs enough detail to act, not a wall of text.

Error context (from target: $TARGET_LABEL):
---
$CONTEXT
---

End your reply with a fenced ===DIGEST=== block containing sections 1-5 above."

DELEGATE_ARGS=("--tier" "$TIER" "--timeout" "$TIMEOUT")
[ -n "$RUN_DIR" ] && DELEGATE_ARGS+=("--dir" "$RUN_DIR")
[ "$APPLY" -eq 1 ] && DELEGATE_ARGS+=("--write")
[ "$PRINT_CMD" -eq 1 ] && DELEGATE_ARGS+=("--print-command")

"$DELEGATE" "${DELEGATE_ARGS[@]}" "$PROMPT"
