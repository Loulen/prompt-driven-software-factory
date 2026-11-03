---
title: Check the factory's health
kind: agent
command: /verify-factory
---

## What you do

You type `/verify-factory`. It runs the factory's health check and reports, item by item, what
passes and what is missing. For anything missing, it offers to fix it. It ends with the next step.

## Under the hood

It probes the wiring the other skills rely on: both backlogs reachable (here, writable folders),
triage labels, the agentic test driver (a terminal app like this one: `tmux`), the scaffold and
the context present, factory files versioned (not git-ignored), git-flow health (`develop` exists),
and whether the user story layout is still the default.

It is **guided, not gated**: it reports and proposes, it never blocks you. Re-run it any time on
your project, it is the fastest way to know where a factory stands. It writes nothing unless you
accept a fix.
