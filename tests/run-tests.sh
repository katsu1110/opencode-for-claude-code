#!/usr/bin/env bash

set -uo pipefail

echo "Running OFFLINE unit tests for opencode-for-claude-code..."

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/oc-delegate.sh"
JOB="$PLUGIN_DIR/scripts/oc-job.sh"
COST="$PLUGIN_DIR/scripts/oc-cost-compare.sh"
DIAG="$PLUGIN_DIR/scripts/diagnose.sh"
MEASURE="$PLUGIN_DIR/scripts/measure-session.py"

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

# ======= oc-delegate.sh tests =======

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

# (f) empty prompt exits 1
test_f() {
  ! "$SCRIPT" "" 2>/dev/null
}

# (g) missing binary exits 13 + stderr contains OC_SIGNAL OPENCODE_MISSING
test_g() {
  out="$(env PATH="/usr/bin:/bin" HOME="$TMP_DIR" "$SCRIPT" "hello" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 13" && echo "$out" | grep -q "OC_SIGNAL" && echo "$out" | grep -q "OPENCODE_MISSING"
}

# Stub opencode for remaining delegate tests
cat > "$TMP_DIR/bin/opencode" << 'INNER_EOF'
#!/bin/bash
if [ "$1" = "run" ]; then
  if [ "$*" = "run -m opencode-go/deepseek-v4-flash quota" ]; then
    echo "429 too many requests" >&2
    exit 1
  elif [ "$*" = "run -m opencode-go/deepseek-v4-flash auth" ]; then
    echo "unauthorized access" >&2
    exit 1
  elif [ "$*" = "run -m opencode-go/deepseek-v4-flash modelbad" ]; then
    echo "model not found: opencode-go/deepseek-v4-flash" >&2
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

# (m) malformed timeout suffixes are rejected
test_m() {
  ! "$SCRIPT" --timeout 10ms --print-command "x" 2>/dev/null
}

# (n) fractional and non-numeric timeouts rejected
test_n() {
  ! "$SCRIPT" --timeout 10.5m --print-command "x" 2>/dev/null &&
  ! "$SCRIPT" --timeout m --print-command "x" 2>/dev/null
}

# (o) valid seconds timeout accepted
test_o() {
  out="$("$SCRIPT" --timeout 300s --print-command "x")"
  echo "$out" | grep -q -- "-m opencode-go/deepseek-v4-flash"
}

# (p) --mode accept-edits adds --auto
test_p() {
  out="$("$SCRIPT" --mode accept-edits --print-command "x")"
  echo "$out" | grep -q -- "--auto"
}

# (p2) --mode plan does not add --auto
test_p2() {
  out="$("$SCRIPT" --mode plan --print-command "x")"
  ! echo "$out" | grep -q -- "--auto"
}

# (q) --mode bogus exits 1
test_q() {
  ! "$SCRIPT" --mode bogus "x" 2>/dev/null
}

# (r) model-unavailable exit 14
test_r() {
  out="$("$SCRIPT" "modelbad" 2>&1 || echo "exit $?")"
  echo "$out" | grep -q "exit 14" && echo "$out" | grep -q "MODEL_UNAVAILABLE"
}

# (s) write-task warning (implement prompt without --write)
test_s() {
  out="$("$SCRIPT" "implement the parser" 2>&1)"
  echo "$out" | grep -qi "write task"
}

# (t) write-task warning suppressed with --write / --mode accept-edits
test_t() {
  out="$("$SCRIPT" --write "implement the parser" 2>&1)"
  if echo "$out" | grep -qi "write task"; then return 1; fi
  out2="$("$SCRIPT" --mode accept-edits "implement the parser" 2>&1)"
  if echo "$out2" | grep -qi "write task"; then return 1; fi
  return 0
}

# (u) WSL slow-mount guard (fires with WSL_DISTRO_NAME + /mnt dir)
test_u() {
  out="$(WSL_DISTRO_NAME=Ubuntu "$SCRIPT" --dir /mnt/c/proj --print-command "x" 2>&1)"
  echo "$out" | grep -q "9p bridge"
}

# (v) WSL no false positive on Linux FS
test_v() {
  out="$(WSL_DISTRO_NAME=Ubuntu "$SCRIPT" --dir /home/u/proj --print-command "x" 2>&1)"
  ! echo "$out" | grep -q "9p bridge"
}

HOOK="$PLUGIN_DIR/hooks/validate-delegate-bash.sh"

# (w) hook rejects prefix-lookalike
test_w() {
  ! printf '%s' '{"tool_input":{"command":"backdoor-oc-delegate x"}}' | "$HOOK" 2>/dev/null
}

# (x) hook rejects cat pipe
test_x() {
  ! printf '%s' '{"tool_input":{"command":"cat /etc/passwd | oc-delegate -"}}' | "$HOOK" 2>/dev/null
}

# (y) hook accepts printf pipe to path
test_y() {
  printf '%s' '{"tool_input":{"command":"printf x | /usr/local/bin/oc-delegate -"}}' | "$HOOK" 2>/dev/null
}

# (z) hook accepts oc-job
test_z() {
  printf '%s' '{"tool_input":{"command":"oc-job status abc"}}' | "$HOOK" 2>/dev/null
}

# (aa) hook accepts oc-cost-compare
test_aa() {
  printf '%s' '{"tool_input":{"command":"oc-cost-compare --tier flash hello"}}' | "$HOOK" 2>/dev/null
}

# (aaa) hook accepts oc-diagnose
test_aaa() {
  printf '%s' '{"tool_input":{"command":"oc-diagnose --dir . error.log"}}' | "$HOOK" 2>/dev/null
}

# ======= bin/ shim tests =======
BIN="$PLUGIN_DIR/bin"

# (ab) bin/ shims exist and are executable
test_ab() {
  for b in oc-delegate oc-job oc-doctor oc-cost-compare oc-diagnose; do
    [ -x "$BIN/$b" ] || return 1
  done
  return 0
}

# (ac) bin/oc-job forwards to the wrapper (no CLAUDE_PLUGIN_ROOT)
test_ac() {
  out="$(env -u CLAUDE_PLUGIN_ROOT "$BIN/oc-job" 2>&1 || true)"
  echo "$out" | grep -qi "usage"
}

# (ad) bin/oc-doctor forwards
test_ad() {
  out="$(env -u CLAUDE_PLUGIN_ROOT "$BIN/oc-doctor" 2>/dev/null | head -1)"
  echo "$out" | grep -qi "doctor"
}

# (ae) bin/oc-cost-compare --help shows help
test_ae() {
  "$BIN/oc-cost-compare" --help 2>/dev/null | grep -qi "usage"
}

# ======= hooks tests =======
CHECK="$PLUGIN_DIR/hooks/check-oc.sh"
INJECT="$PLUGIN_DIR/hooks/inject-policy.sh"
NUDGE="$PLUGIN_DIR/hooks/nudge-delegation.sh"

# (af) check-oc exits 0 when opencode is present (stub)
test_af() {
  "$CHECK" 2>/dev/null
}

# (ag) check-oc exits 0 when opencode is absent, but warns
test_ag() {
  err=$( { PATH="/usr/bin:/bin" "$CHECK" >/dev/null; } 2>&1 )
  echo "$err" | grep -qi "not found"
}

# (ah) inject-policy default on -> emits additionalContext
test_ah() {
  out="$("$INJECT" 2>/dev/null)"
  echo "$out" | grep -q "additionalContext"
}

# (ai) inject-policy off -> no output
test_ai() {
  out="$(CLAUDE_PLUGIN_OPTION_CODING_POLICY=off "$INJECT" 2>/dev/null)"
  [ -z "$out" ]
}

# (aj) inject-policy emits valid SessionStart JSON
test_aj() {
  out="$("$INJECT" 2>/dev/null)"
  printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart"' 2>/dev/null
}

# (ak) nudge fires on bulk EN prompt
test_ak() {
  out=$(printf '%s' '{"prompt":"migrate every caller from APIv1 to APIv2 across the codebase"}' | "$NUDGE" 2>/dev/null)
  echo "$out" | grep -q "additionalContext"
}

# (al) nudge silent on small prompt
test_al() {
  out=$(printf '%s' '{"prompt":"fix the typo in README"}' | "$NUDGE" 2>/dev/null)
  [ -z "$out" ]
}

# (am) nudge silent when already delegating
test_am() {
  out=$(printf '%s' '{"prompt":"/opencode:delegate migrate everything"}' | "$NUDGE" 2>/dev/null)
  [ -z "$out" ]
}

# (an) nudge off suppresses
test_an() {
  out=$(printf '%s' '{"prompt":"migrate all files"}' | CLAUDE_PLUGIN_OPTION_DELEGATION_NUDGE=off "$NUDGE" 2>/dev/null)
  [ -z "$out" ]
}

# ======= hooks.json structural shape =======
# (ao) hooks.json has SessionStart and UserPromptSubmit
test_ao() {
  python3 - "$PLUGIN_DIR/hooks/hooks.json" <<'PY' 2>/dev/null
import json,sys
hooks=json.load(open(sys.argv[1]))["hooks"]
assert hooks.get("SessionStart") and hooks.get("UserPromptSubmit")
for groups in hooks.values():
    assert isinstance(groups,list) and groups
    for g in groups:
        for h in g["hooks"]:
            assert h["type"]=="command" and "CLAUDE_PLUGIN_ROOT" in h["command"]
PY
}

# ======= plugin contract tests =======
# (ap) plugin contract (manifests, hook/agent refs, frontmatter, exec bits)
test_ap() {
  python3 - "$PLUGIN_DIR" <<'PY' 2>/dev/null
import json, os, re, sys, glob

root = sys.argv[1]
def p(*a): return os.path.join(root, *a)
errs = []

pj = json.load(open(p(".claude-plugin", "plugin.json")))
assert pj.get("name") == "opencode", "plugin.json name != opencode"
assert bool(pj.get("version")), "plugin.json missing version"
assert "coding_policy" in pj.get("userConfig", {}), "plugin.json missing coding_policy"
assert "delegation_nudge" in pj.get("userConfig", {}), "plugin.json missing delegation_nudge"

mp = json.load(open(p(".claude-plugin", "marketplace.json")))
plugins = mp.get("plugins", [])
assert plugins and plugins[0].get("source") == "./", "marketplace plugins[0].source != ./"
assert plugins and plugins[0].get("name") == pj.get("name"), "marketplace plugin name != plugin.json name"

hj = json.load(open(p("hooks", "hooks.json")))
cmds = [h["command"] for groups in hj["hooks"].values() for grp in groups for h in grp["hooks"]]
assert cmds, "no hook commands"
for c in cmds:
    m = re.search(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"']+)", c)
    assert m, "hook command missing CLAUDE_PLUGIN_ROOT path: " + c
    assert os.path.isfile(p(m.group(1))), "hook references missing file: " + m.group(1)

for f in glob.glob(p("commands", "*.md")) + [p("skills", "opencode", "SKILL.md"), p("agents", "opencode-delegate.md")]:
    assert os.path.isfile(f), "missing file: " + f
    if os.path.isfile(f):
        t = open(f).read()
        assert t.startswith("---") and t.count("---") >= 2, "no YAML frontmatter: " + os.path.basename(f)

agent = open(p("agents", "opencode-delegate.md")).read()
m = re.search(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"']+\.sh)", agent)
assert m, "agent PreToolUse gate path not found"
assert os.path.isfile(p(m.group(1))), "agent gate references missing file: " + m.group(1)

for s in ("hooks/check-oc.sh", "hooks/inject-policy.sh", "hooks/validate-delegate-bash.sh", "hooks/nudge-delegation.sh"):
    assert os.access(p(s), os.X_OK), "not executable: " + s

for b in ("oc-delegate", "oc-job", "oc-doctor", "oc-cost-compare", "oc-diagnose"):
    assert os.access(p("bin", b), os.X_OK), "bin entrypoint missing/not executable: bin/" + b

for f in glob.glob(p("commands", "*.md")) + [p("skills", "opencode", "SKILL.md")]:
    if os.path.isfile(f):
        t = open(f).read()
        assert "CLAUDE_PLUGIN_ROOT}/scripts/" not in t and "CLAUDE_PLUGIN_ROOT/scripts/" not in t, \
            "invokes $CLAUDE_PLUGIN_ROOT/scripts (empty on model Bash): " + os.path.basename(f)

# SKILL.md version frontmatter must track plugin.json
skill_txt = open(p("skills", "opencode", "SKILL.md")).read()
sm = re.search(r"(?m)^version:\s*(\S+)\s*$", skill_txt)
assert sm, "SKILL.md missing version frontmatter"
assert sm.group(1) == pj.get("version"), "SKILL.md version (%s) != plugin.json version (%s)" % (sm.group(1), pj.get("version"))

prices = json.load(open(p("prices.json")))
assert "deepseek_v4_flash" in prices, "prices.json missing deepseek_v4_flash"
assert "claude_opus" in prices, "prices.json missing claude_opus"

if errs:
    print("CONTRACT FAIL:")
    for e in errs: print("  -", e)
    sys.exit(1)
PY
}

# ======= oc-job.sh tests =======
# (aq) oc-job --help shows usage
test_aq() {
  "$JOB" --help 2>/dev/null | grep -qi "usage"
}

# (ar) oc-job start with no args exits 1
test_ar() {
  ! "$JOB" start 2>/dev/null
}

# (as) oc-job list with no registry returns cleanly
test_as() {
  out="$(OPENCODE_JOBS="$TMP_DIR/jobs" "$JOB" list 2>/dev/null)"
  [ "$out" = "(no jobs)" ] || [ -z "$out" ]
}

# ======= oc-cost-compare.sh tests =======
# (at) oc-cost-compare --help shows usage
test_at() {
  "$COST" --help 2>/dev/null | grep -qi "usage"
}

# (au) oc-cost-compare with no prompt exits 1
test_au() {
  ! "$COST" 2>/dev/null
}

# ======= measure-session.py tests =======
# (av) measure with missing file exits 1
test_av() {
  ! python3 "$MEASURE" /no/such/file 2>/dev/null
}

# (aw) measure with valid session data works
test_aw() {
  SESS="$TMP_DIR/sess.jsonl"
  cat > "$SESS" <<'JSONL'
{"message":{"role":"user","content":"hi"}}
{"message":{"role":"assistant","usage":{"output_tokens":10,"input_tokens":2,"cache_read_input_tokens":100},"content":[{"type":"tool_use","name":"Bash"}]}}
{"message":{"role":"assistant","usage":{"output_tokens":5}}}
JSONL
  out=$(python3 "$MEASURE" "$SESS" "T" 2>/dev/null)
  echo "$out" | grep -q "TOTAL tokens" && echo "$out" | grep -q "COST-WEIGHTED" && echo "$out" | grep -q "turns"
}

# ======= prices.json validation =======
# (ax) prices.json is valid JSON
test_ax() {
  python3 -c "import json; json.load(open('$PLUGIN_DIR/prices.json'))"
}

# ======= run tests =======
run_test "(a)  --print-command tier mapping" test_a
run_test "(b)  --write adds --auto" test_b
run_test "(c)  --digest appends trailer" test_c
run_test "(d)  --dir twice exits 1" test_d
run_test "(e)  unknown option exits 1" test_e
run_test "(f)  empty prompt exits 1" test_f
run_test "(g)  missing binary exits 13" test_g
run_test "(h)  429 yields exit 10" test_h
run_test "(i)  unauthorized yields exit 11" test_i
run_test "(j)  empty output yields exit 3" test_j
run_test "(k)  hello yields exit 0" test_k
run_test "(l)  TIER override" test_l
run_test "(m)  malformed timeout rejected" test_m
run_test "(n)  fractional/non-numeric timeout rejected" test_n
run_test "(o)  valid timeout accepted" test_o
run_test "(p)  --mode accept-edits passes through" test_p
run_test "(q)  --mode bogus exits 1" test_q
run_test "(r)  model-unavailable exit 14" test_r
run_test "(s)  write-task warning fires" test_s
run_test "(t)  write-task warning suppressed with --write" test_t
run_test "(u)  WSL slow-mount guard fires" test_u
run_test "(v)  WSL no false positive on Linux FS" test_v
run_test "(w)  hook rejects prefix lookalike" test_w
run_test "(x)  hook rejects cat pipe" test_x
run_test "(y)  hook accepts printf pipe to path" test_y
run_test "(z)  hook accepts oc-job" test_z
run_test "(aa) hook accepts oc-cost-compare" test_aa
run_test "(aaa) hook accepts oc-diagnose" test_aaa
run_test "(ab) bin/ shims exist and executable" test_ab
run_test "(ac) bin/oc-job forwards" test_ac
run_test "(ad) bin/oc-doctor forwards" test_ad
run_test "(ae) bin/oc-cost-compare shows help" test_ae
run_test "(af) check-oc exits 0 (opencode present)" test_af
run_test "(ag) check-oc warns on absent" test_ag
run_test "(ah) inject-policy emits context" test_ah
run_test "(ai) inject-policy off -> no output" test_ai
run_test "(aj) inject-policy valid SessionStart JSON" test_aj
run_test "(ak) nudge fires on bulk prompt" test_ak
run_test "(al) nudge silent on small prompt" test_al
run_test "(am) nudge silent when delegating" test_am
run_test "(an) nudge=off suppresses" test_an
run_test "(ao) hooks.json structural shape" test_ao
run_test "(ap) plugin contract" test_ap
run_test "(aq) oc-job --help shows usage" test_aq
run_test "(ar) oc-job start no-args exits 1" test_ar
run_test "(as) oc-job list clean no-jobs" test_as
run_test "(at) oc-cost-compare --help shows usage" test_at
run_test "(au) oc-cost-compare no-prompt exits 1" test_au
run_test "(av) measure-session missing file exits 1" test_av
run_test "(aw) measure-session with valid data" test_aw
run_test "(ax) prices.json valid JSON" test_ax

# ======= diagnose.sh tests =======
# (ay) diagnose --help shows full usage including option list
test_ay() {
  out="$("$DIAG" --help 2>/dev/null)"
  echo "$out" | grep -qi "usage" && echo "$out" | grep -qi "\-\-tier"
}

# (az) diagnose with no args exits 1
test_az() {
  ! "$DIAG" 2>/dev/null
}

# (az2) diagnose rejects option without value
test_az2() {
  ! "$DIAG" --tier 2>/dev/null && ! "$DIAG" --dir 2>/dev/null && ! "$DIAG" --timeout 2>/dev/null
}

# (ba) diagnose with existing file works (dry-run)
test_ba() {
  TMP_LOG="$TMP_DIR/err.log"
  echo "ERROR: test failure" > "$TMP_LOG"
  out="$("$DIAG" --print-command "$TMP_LOG" 2>/dev/null)"
  echo "$out" | grep -qi -- "-m opencode-go"
}

# (bb) bin/oc-diagnose forwards to diagnose script
test_bb() {
  out="$("$BIN/oc-diagnose" --help 2>/dev/null)"
  echo "$out" | grep -qi "usage" && echo "$out" | grep -qi "\-\-tier"
}

# (bc) diagnose with stdin (-) works (dry-run)
test_bc() {
  out="$(echo "ERROR: test failure" | "$DIAG" --print-command - 2>/dev/null)"
  echo "$out" | grep -qi -- "-m opencode-go"
}

# (bd) diagnose honors CLAUDE_PLUGIN_OPTION_DEFAULT_TIER
test_bd() {
  out="$(CLAUDE_PLUGIN_OPTION_DEFAULT_TIER=pro "$DIAG" --print-command "$TMP_DIR/err.log" 2>/dev/null)"
  echo "$out" | grep -q -- "-m opencode-go/glm-5.2"
}

run_test "(ay) diagnose --help shows full usage" test_ay
run_test "(az) diagnose no-args exits 1" test_az
run_test "(az2) diagnose missing option value exits 1" test_az2
run_test "(ba) diagnose file works" test_ba
run_test "(bb) bin/oc-diagnose forwards" test_bb
run_test "(bc) diagnose stdin works" test_bc
run_test "(bd) diagnose honors plugin env defaults" test_bd

echo "---"
if [ "$fail_count" -eq 0 ]; then
  echo "Summary: All tests passed."
  exit 0
else
  echo "Summary: $fail_count test(s) failed."
  exit 1
fi
