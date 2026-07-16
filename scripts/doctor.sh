#!/usr/bin/env bash
#
# doctor.sh — read-only health check for the "OpenCode for Claude Code" plugin.
# Verifies the opencode CLI is installed + authenticated and the plugin is wired up.
#
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
ok()   { printf '  ✓ %s\n' "$*"; }
bad()  { printf '  ✗ %s\n' "$*"; FAIL=1; }
warn() { printf '  ⚠ %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
FAIL=0

echo "OpenCode for Claude Code — doctor"

# 1. opencode on PATH
OPENCODE_BIN="$(command -v opencode || true)"
[ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OPENCODE_BIN="$HOME/.opencode/bin/opencode"
if [ -n "$OPENCODE_BIN" ] && [ -x "$OPENCODE_BIN" ]; then
  ok "opencode found: $OPENCODE_BIN  ($("$OPENCODE_BIN" --version 2>/dev/null | head -1))"
else
  bad "opencode NOT on PATH or at ~/.opencode/bin/opencode"
  info "fix: install with: curl -fsSL https://opencode.ai/install | bash"
fi

# 2. opencode authenticated (can list Go models)
if [ -n "$OPENCODE_BIN" ] && [ -x "$OPENCODE_BIN" ]; then
  MODELS="$("$OPENCODE_BIN" models 2>/dev/null || true)"
  if printf '%s' "$MODELS" | grep -q "opencode-go/"; then
    ok "opencode authenticated — Go models available"
    FLASH="${CLAUDE_PLUGIN_OPTION_TIER_FLASH:-opencode-go/deepseek-v4-flash}"
    CODE="${CLAUDE_PLUGIN_OPTION_TIER_CODE:-opencode-go/kimi-k2.7-code}"
    PRO="${CLAUDE_PLUGIN_OPTION_TIER_PRO:-opencode-go/glm-5.2}"
    for m in "$FLASH" "$CODE" "$PRO"; do
      if printf '%s' "$MODELS" | grep -qF "$m"; then
        ok "tier model present: $m"
      else
        warn "tier model not in 'opencode models': $m"
        info "remap tiers via CLAUDE_PLUGIN_OPTION_TIER_* or set _DEFAULT_MODEL"
      fi
    done
  else
    bad "opencode models does NOT list any opencode-go/ models (auth issue?)"
    info "fix: run 'opencode auth login' or /connect in the TUI"
  fi
fi

# 3. Plugin scripts executable
for s in oc-delegate.sh oc-job.sh oc-cost-compare.sh; do
  if [ -x "$HERE/$s" ]; then ok "$s executable"; else
    bad "$s not executable"; info "fix: chmod +x \"$HERE/$s\""
  fi
done

# 3b. SessionStart hooks executable
for h in check-oc.sh inject-policy.sh nudge-delegation.sh validate-delegate-bash.sh; do
  if [ -x "$ROOT/hooks/$h" ]; then ok "hooks/$h executable"; else
    bad "hooks/$h not executable"; info "fix: chmod +x \"$ROOT/hooks/$h\""
  fi
done

# 3c. bin/ entrypoints executable
for b in oc-delegate oc-job oc-doctor oc-cost-compare; do
  if [ -x "$ROOT/bin/$b" ]; then ok "bin/$b executable"; else
    bad "bin/$b not executable"; info "fix: chmod +x \"$ROOT/bin/$b\""
  fi
done

# 3d. WSL check
if grep -qi microsoft /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
  case "$PWD" in
    /mnt/*)
      warn "WSL + workspace on a Windows mount ($PWD)"
      info "opencode --dir reads this over a slow 9p bridge. Move the repo into the WSL Linux FS (~) for ~10x faster I/O." ;;
    *) ok "WSL detected; workspace is on the Linux filesystem" ;;
  esac
fi

# 4. Plugin version
PJ="$ROOT/.claude-plugin/plugin.json"
[ -f "$PJ" ] && ok "plugin: $(sed -n 's/.*"version"[: ]*"\([^"]*\)".*/v\1/p' "$PJ" | head -1)"

echo ""
if [ "$FAIL" -eq 0 ]; then echo "All checks passed — ready to delegate."; else
  echo "Some checks failed — see fixes above."; fi
exit "$FAIL"
