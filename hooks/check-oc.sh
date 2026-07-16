#!/usr/bin/env bash
#
# SessionStart hook: lightweight check that the OpenCode CLI is usable.
# Warns on stderr but NEVER fails the session (always exits 0). The full health
# check lives in scripts/doctor.sh — this one stays fast (no `opencode models`
# network call) so it doesn't slow every session start.
#
set -uo pipefail

OPENCODE_BIN="$(command -v opencode || true)"
[ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OPENCODE_BIN="$HOME/.opencode/bin/opencode"

if [ -z "$OPENCODE_BIN" ]; then
  echo "[opencode plugin] Warning: opencode CLI not found. Install: curl -fsSL https://opencode.ai/install | bash" >&2
  exit 0
fi

if ! "$OPENCODE_BIN" --version >/dev/null 2>&1; then
  echo "[opencode plugin] Warning: opencode is on PATH but '--version' failed — it may need authentication (run \`opencode auth login\`)." >&2
fi

exit 0
