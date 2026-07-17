---
name: Bug report
about: Report a problem with the opencode-for-claude-code plugin
labels: bug
---

## Describe the bug

A clear and concise description of what is not working.

## To Reproduce

Steps to reproduce the behavior, including the exact prompt or delegate task you used.

## Expected behavior

What you expected to happen instead.

## Environment

- **OS:** (e.g. macOS 14, Ubuntu 22.04, WSL/Windows 11)
- **Claude Code version:** (`claude --version`)
- **Plugin version:** (check with `/opencode:setup` or `oc-doctor`)
- **OpenCode CLI version:** (`opencode --version`)

## Doctor output

Run `/opencode:setup` (or `bash scripts/doctor.sh` from the plugin root) and paste the output below:

```
(doctor output here)
```

## Plugin configuration

List any changes from default userConfig (e.g. custom `default_tier`, `timeout`, `tier_*`, `--model` overrides):

## Logs / stderr

Paste any relevant error output. Look for `OC_SIGNAL` lines on stderr — those are machine-readable and very helpful.

## Additional context

Anything else that might help diagnose the issue.
