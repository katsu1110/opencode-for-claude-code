# A/B Results — OpenCode for Claude Code

## How to measure

The plugin ships two measurement tools:

1. **`measure-session.py`** — measures Claude-side token consumption from session
   transcripts. Run it on a session JSONL:

   ```bash
   python3 scripts/measure-session.py <session-id-or-path> [label]
   ```

2. **`oc-cost-compare.sh`** — delegates ONE task to opencode and estimates what
   the same token volume would cost on Claude vs. OpenCode Go:

   ```bash
   oc-cost-compare.sh --tier flash "your task"
   ```

---

## Known data points

No systematic A/B results are published for this plugin yet. Contributions
welcome! If you run a comparison, please submit a PR adding your results below.

### Template for submissions

```markdown
### [Your label, e.g. "Payment module test generation"]
- **Date:** YYYY-MM-DD
- **Repo:** github.com/user/repo (public or describe the domain)
- **Task:** Short description
- **Claude-only baseline:** X tokens, $Y (estimated)
- **Hybrid (Claude + opencode):** X tokens Claude side, Y tokens opencode side, $Z
- **Saving:** ~Nx cheaper, or $N saved per session
- **Notes:** Anything unusual? Quality difference?
```

---

## Caveats

- **Token estimates are ballpark.** `measure-session.py` counts exact Claude tokens
  from the session transcript. opencode token counts are estimated from character
  count (see `oc-cost-compare.sh` for methodology) because `opencode run` does not
  expose a token usage API.
- **The real saving is larger than per-task comparison suggests.** The dominant cost
  in a long session is `cache_read` — Claude re-reading a growing context across
  many turns. By keeping Claude's context lean (digests, not dumps), the hybrid
  pattern reduces `cache_read` dramatically. Per-task token counts don't capture this.
- **`measure-session.py` scope:** Measures the main session loop only. Subagent
  and workflow transcripts are separate files and not counted.
