---
title: Implement one ticket
kind: agent
command: /implement
---

## What you do

You type `/implement` with the first ticket. Then you mostly watch: the agent works on its own and
comes back when the ticket is done, or when it is blocked.

## Under the hood

`/implement` creates a `feature/<ticket>-<slug>` branch from the integration branch and loops three
roles until everything is green:

- `/tdd` — red, then green: first a failing test that states the rule ("submitting a belt with an
  objective left is refused, and names it"), then the code that makes it pass.
- `/code-review` — an independent reviewer checks the diff against the repo's standards and the
  ticket.
- `/agentic-tests` — a subagent drives the real system through its primary surface (here, the
  Blackbelt CLI in a terminal) along the ticket's Feature Path.

When build, tests and Feature Path are green with no blocking finding, the ticket auto-merges into
the integration branch. Merging `integration/*` into `develop` stays a human decision.
