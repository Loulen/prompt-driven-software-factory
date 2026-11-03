---
title: Bootstrap the project context
kind: agent
command: /build-factory
---

## What you do

You type `/build-factory` again. The ports are wired and `CONTEXT.md` is still a stub, so it
proposes **context** mode: the project's **first grilling**. Blackbelt has code, so the agent reads
it and asks you about what it can't infer: what a *belt* is, who the *mentor* and the *sensei* are,
why one open belt per discipline. One question at a time. You answer as the domain expert.

## Under the hood

The grilling writes **as decisions crystallise**: the glossary in `CONTEXT.md` (Belt, Discipline,
Objective, Mentor, Sensei… and the words to avoid), and the **foundational ADRs** in `docs/adr/`
for the decisions that had a real alternative. These files are **the reference** for every later
agent: they make the next sessions speak the project's language.

The context mode has no business story and no integration branch: its output lands on `develop`,
so every later story inherits it. Only the grilling sessions (this one and `/grill-with-docs`) add
to `CONTEXT.md` and the ADRs; every other skill only reads them. On an existing project of real
size, budget half a day for this session.
