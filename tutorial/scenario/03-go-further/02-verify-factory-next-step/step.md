---
title: /verify-factory, your "what's next" oracle
kind: reading
command: /verify-factory
---

## What you do

When you don't know where a factory stands (yours, or one you just joined), run `/verify-factory`.
It ends every report with the sensible next step: wire a missing port, bootstrap the context,
create `develop`, add triage labels…

## Under the hood

The factory is **guided, not gated**: no skill blocks you for skipping a step, but each one knows
the current phase and signposts the next one. `/verify-factory` is that signpost on demand. It
reads the repo state, reports, and fixes only what you accept.
