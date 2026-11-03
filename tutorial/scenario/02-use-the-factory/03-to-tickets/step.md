---
title: Slice the spec into tickets
kind: agent
command: /to-tickets
---

## What you do

You type `/to-tickets`. It proposes a cut of the spec into **tickets**, each a **vertical slice**
(a thin path through every layer, demoable on its own), and asks you to validate the cut before
publishing.

## Under the hood

Each ticket is self-contained, so an agent can pick it up with no human context. It declares what
blocks it and carries its **Feature Path**: the executable acceptance journey that gates its merge.
Tickets an agent can take alone get the `ready-for-agent` triage role. Here they are markdown files
under `.scratch/<feature>/tickets/`.

The skill then **posts back** to the business story the list of tickets it created, for two-way
traceability: here, a `## Comments` section at the bottom of the story file. On Jira or Notion,
that is a comment on the story. If the business tool can't be reached by the agent, this back-link
becomes a manual gesture. N business stories ≠ N tickets.
