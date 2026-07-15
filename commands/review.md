---
description: Perform a cross-model first-pass review of code changes
---

Perform a cross-model first-pass review. 
Run this via Bash:
```bash
{ echo "Review this diff for bugs/security/perf, be skeptical. List file:line findings."; git diff ${ARGUMENTS:-}; } | oc-delegate --tier pro --digest -
```
Wait for the findings.
Then, reconcile the findings yourself as the final judge, discarding any false positives and reporting only the valid issues to the user.
