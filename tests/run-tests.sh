#!/usr/bin/env bash

set -uo pipefail

echo "Running OFFLINE unit tests for oc-delegate.sh..."

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/oc-delegate.sh"

export CLAUDE_PLUGIN_OPTION_TIER_FLASH="opencode-go/deepseek-v4-flash"
export CLAUDE_PLUGIN_OPTION_TIER_CODE="opencode-go/kimi-k2.7-code"
export CLAUDE_PLUGIN_OPTION_TIER_PRO="opencode-go/glm-5.2"

TMP_DIR="$(mktemp -d)"
[ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ] || { echo "FATAL: mktemp -d failed"; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT
export HOME="$TMP_DIR"
mkdir -p "$TMP_DIR/bin"
export PATH="$TMP_DIR/bin:$PATH"

fail_count=0

run_test() {
  local name="$1"
  shift
  echo -n "Test: $name ... "
  if ( "$@" ); then
    echo "PASS"
  else
    echo "FAIL"
    fail_count=$((fail_count + 1))
  fi
}

# (a) --print-command tier mapping shows the right -m model
test_a() {
  out="$("$SCRIPT" --tier pro --print-command "x")"
  echo "$out" | grep -q -- "-m opencode-go/glm-5.2"
}

# (b) --write adds --auto
test_b() {
  out="$("$SCRIPT" --write --print-command "x")"
  echo "$out" | grep -q -- "--auto"
}

# (c) --digest appends ===DIGEST===
test_c() {
  out="$("$SCRIPT" --digest --print-command "x")"
  echo "$out" | grep -q "===DIGEST==="
}

# (d) --dir twice exits 1
test_d() {
  ! "$SCRIPT" --dir . --dir . --print-command "x" 2>/dev/null
}

# (e) unknown option exits 1
test_e() {
  ! "$SCRIPT" --foo "x" 2>/dev/null
}

# (f) empty prompt exits 1 (bare no-args prints help and exits 0 by design)
test_f() {
  ! "$SCRIPT" "" 2>/dev/null
}

# (g) missing binary exits 13 + stderr contains OC_SIGNAL OPENCODE_MISSING.
# Use a PATH with coreutils but no opencode (the wrapper needs tr/cut/sed itself),
# and a temp HOME so the ~/.opencode/bin fallback misses.
test_g() {
  out="$(env PATH="/usr/bin:/bin" HOME="$TMP_DIR" "$SCRIPT" "hello" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 13" && echo "$out" | grep -q "OC_SIGNAL" && echo "$out" | grep -q "OPENCODE_MISSING"
}

# Stub opencode for remaining tests
cat > "$TMP_DIR/bin/opencode" << 'INNER_EOF'
#!/bin/bash
if [ "$1" = "run" ]; then
  if [ "$*" = "run -m opencode-go/deepseek-v4-flash quota" ]; then
    echo "429 too many requests" >&2
    exit 1
  elif [ "$*" = "run -m opencode-go/deepseek-v4-flash auth" ]; then
    echo "unauthorized access" >&2
    exit 1
  elif [ "$*" = "run -m opencode-go/deepseek-v4-flash empty" ]; then
    exit 0
  elif [ "$*" = "run -m opencode-go/deepseek-v4-flash hello" ]; then
    echo "hello"
    exit 0
  fi
fi
exit 0
INNER_EOF
chmod +x "$TMP_DIR/bin/opencode"

# (h) stub exits 1 printing 429 -> wrapper exits 10, OC_SIGNAL QUOTA_EXHAUSTED
test_h() {
  out="$("$SCRIPT" "quota" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 10" && echo "$out" | grep -q "QUOTA_EXHAUSTED"
}

# (i) stub exits 1 printing unauthorized -> exit 11
test_i() {
  out="$("$SCRIPT" "auth" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 11"
}

# (j) stub exits 0 printing nothing -> exit 3
test_j() {
  out="$("$SCRIPT" "empty" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 3"
}

# (k) stub exits 0 printing hello -> exit 0 and stdout has hello
test_k() {
  out="$("$SCRIPT" "hello" 2>/dev/null)"
  echo "$out" | grep -q "hello"
}

# (l) CLAUDE_PLUGIN_OPTION_TIER_FLASH override
test_l() {
  export CLAUDE_PLUGIN_OPTION_TIER_FLASH="opencode-go/custom-flash"
  out="$("$SCRIPT" --print-command "x")"
  echo "$out" | grep -q -- "-m opencode-go/custom-flash"
}

# (m) malformed timeout suffixes are rejected (10ms is not 10 minutes)
test_m() {
  ! "$SCRIPT" --timeout 10ms --print-command "x" 2>/dev/null
}

# (n) fractional and non-numeric timeouts are rejected
test_n() {
  ! "$SCRIPT" --timeout 10.5m --print-command "x" 2>/dev/null &&
  ! "$SCRIPT" --timeout m --print-command "x" 2>/dev/null
}

# (o) valid seconds timeout is accepted
test_o() {
  out="$("$SCRIPT" --timeout 300s --print-command "x")"
  echo "$out" | grep -q -- "-m opencode-go/deepseek-v4-flash"
}

HOOK="$PLUGIN_DIR/hooks/validate-delegate-bash.sh"

# (p) hook rejects prefix-lookalike wrapper names
test_p() {
  ! printf '%s' '{"tool_input":{"command":"backdoor-oc-delegate x"}}' | "$HOOK" 2>/dev/null
}

# (q) hook rejects cat piping arbitrary files into the wrapper
test_q() {
  ! printf '%s' '{"tool_input":{"command":"cat /etc/passwd | oc-delegate -"}}' | "$HOOK" 2>/dev/null
}

# (r) hook accepts printf pipe to a fully-qualified wrapper path
test_r() {
  printf '%s' '{"tool_input":{"command":"printf x | /usr/local/bin/oc-delegate -"}}' | "$HOOK" 2>/dev/null
}

run_test "(a) --print-command tier mapping" test_a
run_test "(b) --write adds --auto" test_b
run_test "(c) --digest appends trailer" test_c
run_test "(d) --dir twice exits 1" test_d
run_test "(e) unknown option exits 1" test_e
run_test "(f) empty prompt exits 1" test_f
run_test "(g) missing binary exits 13" test_g
run_test "(h) 429 yields exit 10" test_h
run_test "(i) unauthorized yields exit 11" test_i
run_test "(j) empty output yields exit 3" test_j
run_test "(k) hello yields exit 0" test_k
run_test "(l) TIER override" test_l
run_test "(m) malformed timeout 10ms rejected" test_m
run_test "(n) fractional/non-numeric timeout rejected" test_n
run_test "(o) valid timeout 300s accepted" test_o
run_test "(p) hook rejects prefix lookalike" test_p
run_test "(q) hook rejects cat pipe" test_q
run_test "(r) hook accepts printf pipe to path" test_r

echo "---"
if [ "$fail_count" -eq 0 ]; then
  echo "Summary: All tests passed."
  exit 0
else
  echo "Summary: $fail_count test(s) failed."
  exit 1
fi
