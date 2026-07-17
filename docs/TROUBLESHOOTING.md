# Troubleshooting

Symptom-first fixes for common issues.

## "opencode not found" or exit 13

Install the OpenCode CLI:
```bash
curl -fsSL https://opencode.ai/install | bash
```
Then authenticate: `opencode auth login` (or use `/connect` in the TUI).

## Exit 10 (quota / rate limit)

OpenCode Go limits are dollar-based (~$12/5h, ~$30/wk, ~$60/mo).
Wait for the window to reset, or use a cheaper tier (`flash` instead of `pro`).
Retry with `--continue` to resume where you left off.

## Exit 11 (auth required)

Run `opencode auth login` interactively. Make sure your Go subscription is active.

## Exit 12 (timeout)

The task didn't finish within the `--timeout` limit. Raise it (e.g. `--timeout 30m`)
or narrow the task scope. For long tasks, use a background job: `oc-job start ...`.

## Exit 14 (model unavailable)

The model specified by `--model` / `--tier` / `default_model` is not in your
`opencode models` list. Run `opencode models --refresh` to see available models,
then update your plugin options or pass a correct `--model`.

## Write task reports success but no files changed

In headless mode without `--write` (opencode's `--auto`), opencode will describe
the edits but may NOT write them to your workspace — it may write to its own scratch
or sandbox directory and report "success" while your workspace is unmodified. Always
use `--write` for file-generating tasks, and verify files actually changed with
`git diff --stat`.

## WSL: opencode is very slow; slow startup on every call

If the repo is on a Windows mount (`/mnt/c/...`), opencode reads it over the slow
9p protocol bridge. Even trivial calls can take 20+ seconds. Move the repo to the
WSL Linux filesystem (`~`) for ~10x faster I/O. The plugin checks for this and
warns you when `--dir /mnt/*` is used.

## macOS: `timeout` not available

The wrapper uses its own watchdog mechanism, so `timeout`/`gtimeout` are optional.
Install coreutils for better timeout handling: `brew install coreutils`.

## Headless (`claude -p`): background jobs never complete

In headless mode (`claude -p`), there is no later turn to collect a backgrounded
result. The session exits before the background job finishes. When running headless,
always delegate synchronously (no `oc-job start`); use `oc-delegate` directly.

## Task delegated but result was too verbose (raw dump, not digest)

If opencode returns a wall of text instead of a concise digest, you're not getting
the cost benefit. Re-run with `--digest` to append an output contract that demands
a `===DIGEST===` block. The wrapper also warns on stderr when the response exceeds
the `digest_warn_chars` threshold (default 8000). Heed that warning.

## Model name mismatches after opencode update

OpenCode's model lineup rotates as new models are added and old ones deprecated.
If `oc-delegate` exits 14 after an update, run `opencode models --refresh` to see
the current list, then update your `tier_*` or `default_model` plugin options
accordingly. The doctor (`/opencode:setup`) warns about missing tier models but
does not fail the session.

## Plugin option changes not taking effect

After changing plugin options via the `/plugin` settings UI, run `/reload-plugins`
to reload without restarting the session. If options are passed as environment
variables (`CLAUDE_PLUGIN_OPTION_*`), they take effect on the next shell command.

## Plugin commands not found (slash commands)

Slash commands (`/opencode:delegate`, `/opencode:setup`, etc.) are auto-detected
from `commands/*.md` — no need to register them in `plugin.json`. After adding or
modifying a command file, run `/reload-plugins` to pick it up.

## CLAUDE_PLUGIN_ROOT expands to empty in model-run Bash

`$CLAUDE_PLUGIN_ROOT` is substituted only in structured config files (hooks.json,
MCP config). It is **not** exported as an environment variable to Bash commands
run by the model. This is why the plugin uses `bin/` shims — Claude Code adds the
plugin's `bin/` to the Bash-tool PATH automatically. Always use bare names
(`oc-delegate`, `oc-job`, `oc-doctor`, `oc-diagnose`, `oc-cost-compare`) rather
than paths with `$CLAUDE_PLUGIN_ROOT/scripts/`.
