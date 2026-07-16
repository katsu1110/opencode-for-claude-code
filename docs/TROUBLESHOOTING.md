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
the edits but may NOT write them. Always use `--write` for file-generating tasks,
and verify files actually changed with `git diff --stat`.

## WSL: opencode is very slow

If the repo is on a Windows mount (`/mnt/c/...`), opencode reads it over the slow
9p protocol bridge. Move the repo to the WSL Linux filesystem (`~`) for ~10x
faster I/O.

## macOS: `timeout` not available

The wrapper uses its own watchdog mechanism, but `timeout`/`gtimeout` are optional.
Install coreutils for better timeout handling: `brew install coreutils`.
