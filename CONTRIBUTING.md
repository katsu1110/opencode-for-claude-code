# Contributing

Thanks for your interest! This is an MIT-licensed community project — issues, PRs, and stars all welcome.

## What's especially welcome

- **More A/B data points** — repeat the measured runs for tighter confidence.
- **New SDLC recipes** — when-to-delegate patterns in `skills/opencode/SKILL.md`.
- **Support for other providers/models** — the delegation wrapper is intentionally thin.
- **Real OpenCode Go prices** — keep `prices.json` accurate.

## Dev setup

You need the [OpenCode](https://opencode.ai) CLI (`opencode`, authenticated with a Go subscription) and Claude Code.

```bash
git clone https://github.com/katsu1110/opencode-for-claude-code ~/opencode-for-claude-code
cd ~/opencode-for-claude-code

# load the plugin live from your working tree:
claude --plugin-dir ~/opencode-for-claude-code
```

The scripts also run standalone:

```bash
scripts/oc-delegate.sh --tier flash "Summarize this in 3 bullets: ..."
scripts/oc-job.sh start --tier pro "big task"
scripts/oc-cost-compare.sh --tier flash "hello"
python3 scripts/measure-session.py <session-id>
```

## Before you open a PR

```bash
bash tests/run-tests.sh                    # dependency-free; stubs opencode, no network
shellcheck --severity=error scripts/*.sh tests/*.sh hooks/*.sh   # CI gates on this
```

- **Tests pass** and shellcheck is clean.
- If you touch a manifest, `python3 -c "import json; json.load(open('.claude-plugin/plugin.json'))"` (and `marketplace.json`, `prices.json`) still parse.
- **Keep the skill honest.** `skills/opencode/SKILL.md` is the plugin's brain — if behavior changes, update it.
- **Cost numbers are estimates.** If you quote figures, say so and point at `prices.json`.
- Add a line to `CHANGELOG.md` under "Unreleased".

## Conventions

- Small, focused PRs. Describe *what changed and why*.
- Match the surrounding style — POSIX-ish bash, `set -euo pipefail`, quote expansions.
- New scripts get a `usage()` and a test in `tests/run-tests.sh`.

## Reporting bugs / ideas

Open an issue with what you ran (`opencode --version`, the command, OS) and what you expected vs. saw.
