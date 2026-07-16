# opencode-for-claude-code

A Claude Code plugin that lets Claude delegate well-scoped work to OpenCode Go models via the headless `opencode run` CLI. Claude acts as the conductor (handling planning, the hard 20%, and verification), while OpenCode Go models serve as the cheap executors for high-volume tasks. It is modeled directly on the cost-aware architecture of [`antigravity-for-claude-code`](https://github.com/yuting0624/antigravity-for-claude-code).

## What it is

This plugin enables hybrid agentic engineering. Keep judgement-heavy work on Claude (the frontier model) and route deterministic, bulk work (scaffolding, well-specified implementation, test generation, migrations, first-pass review) to OpenCode Go. It provides the `oc-delegate` bash wrapper to handle routing, timeouts, and structured error signals.

## Requirements

- **Claude Code**: The conductor.
- **opencode CLI**: The executor tool.
- **OpenCode Go Subscription**: A $10/mo subscription providing curated open-source models with dollar-based limits (~$12/5h, ~$30/wk, ~$60/mo).

## Install

```bash
# Add the marketplace
claude plugin marketplace add katsu1110/opencode-for-claude-code

# Install the plugin
claude plugin install opencode
```

## Quickstart Examples

In Claude Code, you can trigger delegations directly or use slash commands:

- `/opencode:setup` - Run the doctor script to check your installation and models.
- `/opencode:delegate Write unit tests for src/auth.py` - Delegate a task.
- `/opencode:review` - Run a cross-model first-pass code review of your uncommitted changes.

Or converse with Claude: "Migrate the legacy endpoints in `src/api/` to the new format. Delegate this to opencode to save tokens, then run the tests to verify."

## Tier Routing

| Tier | Default Model | Best For | Quota Note |
|---|---|---|---|
| `flash` | `opencode-go/deepseek-v4-flash` | Bulk reads, test generation, digests | Cheap (~158k req/mo) |
| `code` | `opencode-go/kimi-k2.7-code` | Implementation against specs | Standard |
| `pro` | `opencode-go/glm-5.2` | Hard reasoning, review, retries | Scarce (~4.3k req/mo) |

*Tiers can be remapped via plugin options.*

## oc-delegate Options

```
Usage:
  oc-delegate.sh [options] "the task prompt"
  echo "long prompt" | oc-delegate.sh [options] -      # read prompt from stdin

Options:
  -t, --tier <flash|code|pro>   Model tier (default: flash)
  -d, --dir <path>              Directory to run in (single dir — opencode limit)
      --timeout <dur>           Wall-clock timeout, e.g. 10m, 300s (default: 10m)
      --write                   Allow file writes / commands (DANGEROUS; run on a branch)
      --mode accept-edits|plan    Execution mode (accept-edits maps to --auto; plan touches nothing)
      --digest                  Append a digest-only output contract to the prompt
  -c, --continue                Resume the most recent opencode session
  -s, --session <id>            Resume a specific opencode session by id
  -m, --model <provider/model>  Exact model (any from `opencode models`)
      --variant <v>             Model variant / reasoning effort
      --print-command           Print the resolved opencode command and exit
  -h, --help                    Show this help
```

## Exit Codes & OC_SIGNAL

- `0` ok | `1` usage | `2` run failed | `3` empty
- `10` quota | `11` auth | `12` timeout | `13` opencode missing | `14` model unavailable
- On classifiable failures, a machine-readable JSON line is printed to stderr: `OC_SIGNAL {"status":"...","reason":"..."}`

## Cost Discipline Summary

- **Break-even**: Only delegate above the break-even point. Do not delegate tiny edits.
- **Digest-not-dump**: Use `--digest` for bulk reads to prevent large dumps from inflating Claude's context.
- **Batch**: Consolidate tasks.
- **Lean Context**: Never paste raw code back into the thread.

## Safety

- `--write` automatically approves commands and file edits. **Always run write tasks on a dedicated branch.**
- Verify files actually changed.
- Never trust the executor's self-reported green status.

## Configuration

Available in `.claude-plugin/plugin.json`:
- `default_tier`: Default tier (`flash`).
- `timeout`: Default timeout (`10m`).
- `coding_policy`: Inject the cost-aware routing policy at SessionStart (`on`/`off`).
- `delegation_nudge`: Add a delegation nudge on bulk-looking prompts (`on`/`off`).
- `default_model`: Exact model to override tier mapping.
- `tier_flash`, `tier_code`, `tier_pro`: Custom mappings for the three tiers.
- `digest_warn_chars`: Warning threshold for large outputs (default 8000).

## FAQ

- **Why a single directory?** `opencode run` is limited to a single `--dir` argument. Always pass the repo root.
- **Why did I hit a quota limit quickly?** Quotas are shared with interactive TUI usage and are dollar-based. A runaway `pro` tier task can burn through the 5h window quickly. Use `flash` when possible.
- **How do I remap models?** Use the `CLAUDE_PLUGIN_OPTION_TIER_*` options in your plugin config to update models as OpenCode's lineup changes.
