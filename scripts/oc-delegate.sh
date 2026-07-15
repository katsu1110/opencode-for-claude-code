#!/usr/bin/env bash
#
# oc-delegate.sh — headless wrapper around the OpenCode CLI (`opencode run`).
# Part of the "OpenCode for Claude Code" plugin.
#
# Purpose: let Claude Code (the conductor) hand a single, well-scoped subtask to
# an OpenCode Go model (cheap curated OSS coding models) and get clean text back
# on stdout — for delegated implementation, test generation, first-pass review,
# or offloading bulk reads that return a digest.
#
# Why a wrapper instead of calling `opencode` directly:
#   * Human-friendly tier names (flash / code / pro) mapped to OpenCode Go models,
#     overridable via plugin userConfig without code changes.
#   * A wall-clock timeout guard (`opencode run` has none; macOS has no timeout(1)).
#   * A guaranteed contract: non-empty stdout on success, non-zero exit + a
#     machine-readable OC_SIGNAL stderr line on classifiable failures, so
#     orchestrators react to structure instead of scraping prose.
#
# Usage:
#   oc-delegate.sh [options] "the task prompt"
#   echo "long prompt" | oc-delegate.sh [options] -      # read prompt from stdin
#
# Options:
#   -t, --tier <flash|code|pro>   Model tier (default: flash)
#                                   flash = bulk/default, code = implementation,
#                                   pro   = hard reasoning/review (scarce quota)
#   -d, --dir <path>              Directory to run in (opencode reads AGENTS.md +
#                                 real files there; single dir — opencode limit)
#       --timeout <dur>           Wall-clock timeout, e.g. 10m, 300s (default: 10m)
#       --write                   Allow file writes / commands: maps to opencode's
#                                 --auto (auto-approve permissions — DANGEROUS;
#                                 run on a branch/worktree)
#       --digest                  Append a digest-only output contract to the prompt
#                                 (ingest digests, not raw dumps — the biggest cost lever)
#   -c, --continue                Resume the most recent opencode session (stateful)
#   -s, --session <id>            Resume a specific opencode session by id (stateful)
#   -m, --model <provider/model>  Exact model (any from `opencode models`)
#       --variant <v>             Model variant / reasoning effort (provider-specific)
#       --print-command           Print the resolved opencode command and exit (dry run)
#   -h, --help                    Show this help
#
# Exit codes: 0 ok | 1 usage | 2 run failed | 3 empty | 10 quota | 11 auth | 12 timeout | 13 opencode missing
#
# On a classifiable failure, a machine-readable line is printed to stderr:
#   OC_SIGNAL {"status":"QUOTA_EXHAUSTED","reason":"...","model":"...","retry":"--continue"}
#
# Tier defaults map to OpenCode Go models but are remappable via plugin userConfig
# (env): CLAUDE_PLUGIN_OPTION_DEFAULT_TIER, _TIMEOUT, _DEFAULT_MODEL, and per-tier
# _TIER_FLASH / _TIER_CODE / _TIER_PRO. Explicit --model/--tier win.
#
set -euo pipefail

TIER="${CLAUDE_PLUGIN_OPTION_DEFAULT_TIER:-flash}"
TIMEOUT="${CLAUDE_PLUGIN_OPTION_TIMEOUT:-10m}"
TIER_EXPLICIT=0
MODEL=""
VARIANT=""
WRITE=0
DIGEST=0
RUN_DIR=""
PROMPT=""
CONTINUE=0
SESSION_ID=""
PRINT_CMD=0

die() { echo "oc-delegate: $*" >&2; exit 1; }
# $1 = remaining argc ($#). Fail with a friendly message if an option has no value.
need() { [ "$1" -ge 2 ] || die "option '$2' needs a value"; }

# Emit a one-line machine-readable failure signal to stderr. $1=status $2=reason.
# QUOTA failures advertise `--continue` so a caller knows how to resume the session
# once the limit window resets.
signal() {
  local status="$1" reason="$2" retry="" model_safe
  [ "$status" = "QUOTA_EXHAUSTED" ] && retry="--continue"
  reason="$(printf '%s' "$reason" | tr '\n\r\t' '   ' | tr -d '"\\' | cut -c1-200)"
  model_safe="$(printf '%s' "${MODEL:-}" | tr -d '"\\')"
  printf 'OC_SIGNAL {"status":"%s","reason":"%s","model":"%s","retry":"%s"}\n' \
    "$status" "$reason" "$model_safe" "$retry" >&2
}

# Print the header comment between "# Usage:" and "# Exit codes:" (anchored to
# content, not line numbers, so it never desyncs when the header changes).
usage() { sed -n '/^# Usage:/,/^# Exit codes:/p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# --- map a tier to a provider/model (see `opencode models`) ---
# Defaults are OpenCode Go models; each tier is remappable via userConfig (env).
model_for_tier() {
  case "$1" in
    flash) echo "${CLAUDE_PLUGIN_OPTION_TIER_FLASH:-opencode-go/deepseek-v4-flash}" ;;
    code)  echo "${CLAUDE_PLUGIN_OPTION_TIER_CODE:-opencode-go/kimi-k2.7-code}" ;;
    pro)   echo "${CLAUDE_PLUGIN_OPTION_TIER_PRO:-opencode-go/glm-5.2}" ;;
    *) die "unknown tier '$1' (use flash | code | pro)" ;;
  esac
}

# --- parse a duration like 10m / 300s / 600 into seconds ---
to_seconds() {
  local d="$1"
  case "$d" in
    *m) echo $(( ${d%m} * 60 )) ;;
    *s) echo "${d%s}" ;;
    *h) echo $(( ${d%h} * 3600 )) ;;
    *[!0-9]*) die "bad --timeout '$d' (use e.g. 10m, 300s)" ;;
    '') die "bad --timeout ''" ;;
    *) echo "$d" ;;
  esac
}

# --- arg parsing ---
[ $# -eq 0 ] && usage
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tier)      need $# "$1"; TIER="$2"; TIER_EXPLICIT=1; shift 2 ;;
    -d|--dir)       need $# "$1"; [ -n "$RUN_DIR" ] && die "--dir given twice (opencode run takes a single --dir)"; RUN_DIR="$2"; shift 2 ;;
    --timeout)      need $# "$1"; TIMEOUT="$2"; shift 2 ;;
    --write)        WRITE=1; shift ;;
    --digest)       DIGEST=1; shift ;;
    -c|--continue)  CONTINUE=1; shift ;;
    -s|--session)   need $# "$1"; SESSION_ID="$2"; shift 2 ;;
    -m|--model)     need $# "$1"; MODEL="$2"; shift 2 ;;
    --variant)      need $# "$1"; VARIANT="$2"; shift 2 ;;
    --print-command) PRINT_CMD=1; shift ;;
    -h|--help)      usage ;;
    -)              PROMPT="$(cat)"; shift ;;
    -*)             die "unknown option '$1' (see --help)" ;;
    *)              [ -n "$PROMPT" ] && die "prompt given twice (quote the whole task as one argument)"; PROMPT="$1"; shift ;;
  esac
done

[ -n "$PROMPT" ] || die "empty prompt"
[ -n "$RUN_DIR" ] && [ ! -d "$RUN_DIR" ] && die "--dir '$RUN_DIR' is not a directory"

# Model precedence: explicit --model > explicit --tier > userConfig default_model > default tier.
if [ -z "$MODEL" ]; then
  if [ "$TIER_EXPLICIT" -eq 0 ] && [ -n "${CLAUDE_PLUGIN_OPTION_DEFAULT_MODEL:-}" ]; then
    MODEL="$CLAUDE_PLUGIN_OPTION_DEFAULT_MODEL"
  else
    MODEL="$(model_for_tier "$TIER")"
  fi
fi

if [ "$DIGEST" -eq 1 ]; then
  PROMPT="$PROMPT

End your reply with a fenced block starting ===DIGEST=== listing: files changed (or key findings), key decisions, and a 1-paragraph 'context for next step'. Put bulky detail ONLY in files, not in your reply."
fi

# --- locate the opencode binary ---
OPENCODE_BIN="$(command -v opencode || true)"
[ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OPENCODE_BIN="$HOME/.opencode/bin/opencode"
if [ -z "$OPENCODE_BIN" ]; then
  signal "OPENCODE_MISSING" "opencode CLI not found on PATH or in ~/.opencode/bin"
  echo "oc-delegate: opencode CLI not found. Install: curl -fsSL https://opencode.ai/install | bash" >&2
  exit 13
fi

# --- assemble the command ---
CMD=("$OPENCODE_BIN" "run" "-m" "$MODEL")
[ -n "$RUN_DIR" ] && CMD+=("--dir" "$RUN_DIR")
[ -n "$VARIANT" ] && CMD+=("--variant" "$VARIANT")
[ "$WRITE" -eq 1 ] && CMD+=("--auto")
[ "$CONTINUE" -eq 1 ] && CMD+=("--continue")
[ -n "$SESSION_ID" ] && CMD+=("--session" "$SESSION_ID")
CMD+=("$PROMPT")

if [ "$PRINT_CMD" -eq 1 ]; then
  printf '%q ' "${CMD[@]}"; printf '\n'
  exit 0
fi

# --- run with a portable wall-clock guard (no timeout(1) on macOS) ---
SECS="$(to_seconds "$TIMEOUT")"
OUT="$(mktemp)"; ERR="$(mktemp)"; TIMED_OUT_MARK="$(mktemp)"
rm -f "$TIMED_OUT_MARK"
RUN_PID=""; WATCHDOG=""
# Also reap the children on any exit (e.g. SIGINT), so an interrupted wrapper
# never leaves an opencode agent running invisibly against the Go quota.
cleanup() {
  # `|| true` throughout: a failed kill in an EXIT trap under `set -e` would
  # otherwise abort the trap and clobber the wrapper's contractual exit code.
  { [ -n "$WATCHDOG" ] && kill "$WATCHDOG" 2>/dev/null; } || true
  { [ -n "$RUN_PID" ] && kill "$RUN_PID" 2>/dev/null; } || true
  rm -f "$OUT" "$ERR" "$TIMED_OUT_MARK" || true
}
trap cleanup EXIT

set +e
"${CMD[@]}" < /dev/null > "$OUT" 2> "$ERR" &
RUN_PID=$!
(
  waited=0
  while kill -0 "$RUN_PID" 2>/dev/null && [ "$waited" -lt "$SECS" ]; do
    sleep 5; waited=$(( waited + 5 ))
  done
  if kill -0 "$RUN_PID" 2>/dev/null; then
    touch "$TIMED_OUT_MARK"
    kill -TERM "$RUN_PID" 2>/dev/null
    sleep 5
    kill -KILL "$RUN_PID" 2>/dev/null
  fi
) &
WATCHDOG=$!
wait "$RUN_PID"; RC=$?
kill "$WATCHDOG" 2>/dev/null; wait "$WATCHDOG" 2>/dev/null
set -e

STDERR_TXT="$(cat "$ERR" 2>/dev/null || true)"
STDOUT_TXT="$(cat "$OUT" 2>/dev/null || true)"

if [ -f "$TIMED_OUT_MARK" ]; then
  signal "TIMEOUT" "no completion within $TIMEOUT"
  echo "oc-delegate: timed out after $TIMEOUT (raise --timeout or narrow the task)" >&2
  exit 12
fi

# --- classify failures from stderr (stdout may quote quota/auth words from the
# task itself, e.g. when the delegated work is about rate limiting) ---
if [ "$RC" -ne 0 ]; then
  if printf '%s' "$STDERR_TXT" | grep -qiE 'quota|rate.?limit|usage.?limit|too many requests|429|overloaded|limit (reached|exceeded)'; then
    signal "QUOTA_EXHAUSTED" "$STDERR_TXT"
    echo "oc-delegate: OpenCode Go usage limit hit (5h/weekly/monthly are dollar-based). Retry after the window resets." >&2
    exit 10
  fi
  if printf '%s' "$STDERR_TXT" | grep -qiE 'unauthorized|not authenticated|authentication|invalid api key|401|forbidden'; then
    signal "AUTH_REQUIRED" "$STDERR_TXT"
    echo "oc-delegate: authentication failed. Run 'opencode auth login' (or /connect in the TUI)." >&2
    exit 11
  fi
  signal "RUN_FAILED" "$STDERR_TXT"
  echo "oc-delegate: opencode run failed (exit $RC)" >&2
  [ -n "$STDERR_TXT" ] && printf '%s\n' "$STDERR_TXT" | tail -20 >&2
  exit 2
fi

if [ -z "$(printf '%s' "$STDOUT_TXT" | tr -d '[:space:]')" ]; then
  signal "EMPTY_OUTPUT" "$STDERR_TXT"
  echo "oc-delegate: opencode returned empty output (try --tier pro or a sharper spec)" >&2
  exit 3
fi

# --- digest-size warning: a dump instead of a digest erases the cost savings ---
WARN_CHARS="${CLAUDE_PLUGIN_OPTION_DIGEST_WARN_CHARS:-8000}"
if [ "$WARN_CHARS" != "0" ] && [ "${#STDOUT_TXT}" -gt "$WARN_CHARS" ]; then
  echo "oc-delegate: WARNING reply is ${#STDOUT_TXT} chars (> $WARN_CHARS) — that's a dump, not a digest. Ingest only the digest; keep bulky detail in files (--digest enforces this)." >&2
fi

printf '%s\n' "$STDOUT_TXT"
