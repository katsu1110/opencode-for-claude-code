#!/usr/bin/env bash

set -uo pipefail

echo "Running OpenCode doctor..."

fail_count=0

pass() { echo "ok: $1"; }
fail() { echo "FAIL: $1"; fail_count=$((fail_count + 1)); }

OPENCODE_BIN="$(command -v opencode || true)"
[ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OPENCODE_BIN="$HOME/.opencode/bin/opencode"

if [ -n "$OPENCODE_BIN" ] && [ -x "$OPENCODE_BIN" ]; then
  pass "opencode binary found at $OPENCODE_BIN"
  
  if "$OPENCODE_BIN" --version >/dev/null 2>&1; then
    pass "\`opencode --version\` succeeded"
  else
    fail "\`opencode --version\` failed"
  fi

  models_out="$("$OPENCODE_BIN" models 2>/dev/null || true)"
  if printf "%s" "$models_out" | grep -q "opencode-go/"; then
    pass "opencode models lists at least one opencode-go/ model"
  else
    fail "opencode models does NOT list any opencode-go/ models (auth issue?)"
  fi

  for m in \
    "${CLAUDE_PLUGIN_OPTION_TIER_FLASH:-opencode-go/deepseek-v4-flash}" \
    "${CLAUDE_PLUGIN_OPTION_TIER_CODE:-opencode-go/kimi-k2.7-code}" \
    "${CLAUDE_PLUGIN_OPTION_TIER_PRO:-opencode-go/glm-5.2}" \
  ; do
    if printf "%s" "$models_out" | grep -q "$m"; then
      pass "model $m available"
    else
      fail "model $m NOT found in opencode models"
    fi
  done
else
  fail "opencode binary not found on PATH or at ~/.opencode/bin/opencode"
fi

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -x "$PLUGIN_DIR/scripts/oc-delegate.sh" ]; then
  pass "scripts/oc-delegate.sh is executable"
  if "$PLUGIN_DIR/scripts/oc-delegate.sh" --print-command "x" >/dev/null 2>&1; then
    pass "\`oc-delegate.sh --print-command \"x\"\` dry-run succeeded"
  else
    fail "\`oc-delegate.sh --print-command \"x\"\` dry-run failed"
  fi
else
  fail "scripts/oc-delegate.sh is not executable or not found"
fi

echo "---"
if [ "$fail_count" -eq 0 ]; then
  echo "Doctor summary: All checks passed. OpenCode is ready."
  exit 0
else
  echo "Doctor summary: $fail_count check(s) failed."
  exit 1
fi
