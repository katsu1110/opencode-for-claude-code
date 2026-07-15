#!/usr/bin/env bash

set -uo pipefail

OPENCODE_BIN="$(command -v opencode || true)"
[ -z "$OPENCODE_BIN" ] && [ -x "$HOME/.opencode/bin/opencode" ] && OPENCODE_BIN="$HOME/.opencode/bin/opencode"

if [ -z "$OPENCODE_BIN" ]; then
  echo "[opencode plugin] Warning: opencode CLI not found. Please install it and run /opencode:setup" >&2
fi

exit 0
