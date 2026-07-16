#!/usr/bin/env bash
#
# oc-cost-compare.sh — run ONE task on opencode (Go model), then show what that same
# token volume would cost on Claude vs on OpenCode Go. A demo aid for the
# "let the cheap model do the bulk tokens" hypothesis.
#
# HONEST SCOPE / CAVEATS:
#   * opencode run has no token usage API, so token counts here are
#     ESTIMATED from character count (chars / CHARS_PER_TOKEN). They are ballpark,
#     not billing-accurate.
#   * This prices the SAME measured volume at both price decks to visualize the
#     per-token price gap. The REAL saving in practice is larger, because Claude
#     as an orchestrator processes far fewer tokens than Claude doing everything.
#   * Prices below come from prices.json. VERIFY against opencode.ai/docs/go/
#     before quoting numbers to anyone. Per 1M tokens, in USD.
#
# Usage:
#   oc-cost-compare.sh [-t flash|code|pro] "the task prompt"
#
# Env overrides (USD per 1M tokens):
#   CLAUDE_IN_PER_M  CLAUDE_OUT_PER_M     (default: 5 / 25   -- VERIFY!)
#   GO_IN_PER_M      GO_OUT_PER_M         (default: from prices.json based on tier)
#   CHARS_PER_TOKEN                       (default: 4)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
TIER="flash"

while [ $# -gt 0 ]; do
  case "$1" in
    -t|--tier) TIER="${2:-flash}"; shift 2 ;;
    -h|--help) sed -n '/^# Usage:/,/^# Env overrides/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --)        shift; break ;;
    -*)        echo "unknown option: $1" >&2; exit 1 ;;
    *)         break ;;
  esac
done
PROMPT="${*:-}"
[ -n "$PROMPT" ] || { echo "usage: oc-cost-compare.sh [-t tier] \"task\"" >&2; exit 1; }

# Default prices from prices.json (env vars still override)
PRICES="$HERE/../prices.json"
# Look up a model key directly (e.g. "claude_opus" → {"in":5,"out":25})
# or a tier name for Go models ("flash" → deepseek_v4_flash → price).
price_for() {
  python3 - "$PRICES" "$@" 2>/dev/null <<'PY' || echo ""
import json,sys
p=json.load(open(sys.argv[1]))
tier=sys.argv[2]
field=sys.argv[3] if len(sys.argv)>3 else ""
m={"flash":"deepseek_v4_flash","code":"kimi_k2_7_code","pro":"glm_5_2"}.get(tier, tier)
deck=p.get(m,{})
if not deck and field:
    print(""); sys.exit(0)
print(deck.get(field, deck) if field else "")
PY
}

CIN="${CLAUDE_IN_PER_M:-$(price_for claude_opus in || echo 5)}"
COUT="${CLAUDE_OUT_PER_M:-$(price_for claude_opus out || echo 25)}"

GIN="${GO_IN_PER_M:-$(price_for "$TIER" in || echo 0.14)}"
GOUT="${GO_OUT_PER_M:-$(price_for "$TIER" out || echo 0.28)}"

CPT="${CHARS_PER_TOKEN:-4}"
case "$CPT" in ''|*[!0-9]*) CPT=4 ;; esac
[ "$CPT" -gt 0 ] || CPT=4

echo ">> Delegating to opencode (tier=$TIER) ..." >&2
START=$(date +%s 2>/dev/null || echo 0)
OUT="$("$HERE/oc-delegate.sh" --tier "$TIER" "$PROMPT")"
END=$(date +%s 2>/dev/null || echo 0)
ELAPSED=$(( END - START ))

IN_CHARS=${#PROMPT}
OUT_CHARS=${#OUT}

awk -v ic="$IN_CHARS" -v oc="$OUT_CHARS" -v cpt="$CPT" \
    -v cin="$CIN" -v cout="$COUT" \
    -v gin="$GIN" -v gout="$GOUT" \
    -v el="$ELAPSED" 'BEGIN {
  it = ic / cpt; ot = oc / cpt;
  cc = it*cin/1e6 + ot*cout/1e6;
  gc = it*gin/1e6 + ot*gout/1e6;
  save = cc - gc;
  ratio = (gc > 0) ? cc / gc : 0;
  printf "\n--- estimated (chars/%d), NOT billing-accurate ---\n", cpt;
  printf "input  ~%d tokens (%d chars)\n", it, ic;
  printf "output ~%d tokens (%d chars)\n", ot, oc;
  printf "elapsed: %ds\n\n", el;
  printf "%-14s %12s %12s\n", "deck", "in $/1M", "out $/1M";
  printf "%-14s %12.2f %12.2f\n", "Claude", cin, cout;
  printf "%-14s %12.2f %12.2f\n\n", "OpenCode Go", gin, gout;
  printf "if priced as Claude: $%.6f\n", cc;
  printf "actual on Go       : $%.6f\n", gc;
  printf "saved on this task : $%.6f  (%.1fx cheaper)\n", save, ratio;
  printf "NOTE: real saving is larger — orchestrator Claude handles far fewer tokens.\n";
}'

echo ""
echo "----- opencode output -----"
printf '%s\n' "$OUT"
