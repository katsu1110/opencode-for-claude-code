---
description: Run the opencode doctor health check and diagnose environment setup
---

Run the plugin's doctor and report status.

Run: `oc-doctor`

Then summarize for the user:
- Is `opencode` installed, and can it list Go models (i.e. authenticated)?
- Are the plugin scripts and bin/ entrypoints executable?
- What default Go models are configured for each tier?

If anything is missing or failing, give the **exact** command to fix it (install
opencode, authenticate, `chmod +x` the scripts, etc.). Keep it short and actionable.
