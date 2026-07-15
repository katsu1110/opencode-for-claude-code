---
description: Delegate a subtask to an OpenCode Go model via oc-delegate
---

Take the user's task from `$ARGUMENTS` and delegate it to the OpenCode Go models via `oc-delegate`.
Decide the appropriate tier per the `SKILL.md` policy (default: flash; code for implementation; pro sparingly for hard reasoning).
Compose and run an `oc-delegate` call.
- Always use `--dir <repo-root>` for repo work.
- Use `--write` only for write tasks, and only if on a branch.
- Use `--digest` for bulk reads.

After `oc-delegate` finishes, verify the results per the skill's gates.
