---
title: Keep the context lean with /clean-context
kind: reading
command: /clean-context
---

## What you do

After a few stories, `CONTEXT.md`, the ADRs and the code comments accumulate. Now and then, run
`/clean-context`: it proposes what to cut, on a dedicated branch and pull request, and you review it.

## Under the hood

It keeps a sentence only if it passes the **named counterfactual** test: you must be able to name
the wrong-but-plausible thing an agent would do without it, which no compiler, test or reading of
the code would catch. Everything else is noise that costs context on every session. It only
deletes and tightens, it never adds. Adding is the grilling sessions' job.
