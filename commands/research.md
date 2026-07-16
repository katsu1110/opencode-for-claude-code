---
description: Claude-orchestrated deep research — OpenCode Go does the grounded web legwork; Claude plans, verifies the citations, and synthesizes
argument-hint: "<what to research>"
---

Run a multi-source research pass on the topic below. OpenCode Go has `webfetch`
and `websearch` (Exa AI) tools. You (Claude) own the plan, the verification, and
the synthesis.

Topic: $ARGUMENTS

If the topic is empty, ask the user what to research before starting.

Do this:
1. **Plan (you).** Break the topic into 3-6 sub-questions. You own scope and synthesis.
2. **Fan-out search (opencode, cheap, one call per sub-question).** Web tools need
   `OPENCODE_ENABLE_EXA=1` and `--write` (opencode's `--auto` grants permissions):
   `OPENCODE_ENABLE_EXA=1 oc-delegate --tier flash --write "Use web search for <sub-question>. Return 5-8 bullet findings, each with the exact source URL. Output ONLY findings + URLs."`
3. **Deepen on key claims (opencode).** Name the URL and have opencode fetch it:
   `oc-delegate --tier pro --write "Open <URL> and quote the exact sentence(s) supporting: '<claim>'. If the page does not support it, reply NOT SUPPORTED."`
4. **Adversarially verify (you).** Corroborate each key claim across >=2 independent
   sources; treat vague/domain-only citations as unverified.
5. **Synthesize (you).** Write a cited report from verified findings only.

Keep your own context lean — ingest opencode's bullet digests, not raw pages.
Re-dispatch follow-up calls to close gaps. In an interactive session, background
long fetches with `oc-job`; when headless (`claude -p`), run synchronously.
