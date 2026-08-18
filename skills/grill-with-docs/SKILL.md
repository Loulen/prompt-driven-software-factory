---
name: grill-with-docs
description: Per-story grilling that stress-tests your plan against the project's domain model, sharpens terminology, and writes CONTEXT.md/ADRs inline as decisions crystallise. Run it when designing a business user story before slicing it into work.
disable-model-invocation: true
---

<what-to-do>

Grill me relentlessly about this plan until we reach a shared understanding, resolving one decision at a time down each branch of the design tree. For each question give your recommended answer, and ask one round at a time — wait for my answer before the next round.

Drive the session with the two support skills: invoke **grilling** for the interview method and **domain-modeling** for the domain-modeling discipline (both are model-invoked, so reach them with the Skill tool).

When a question can be answered from the codebase, find the fact yourself instead of asking me.

</what-to-do>

<supporting-info>

## Branch placement

This session writes versioned context files (`CONTEXT.md`, ADRs). Before the first file write, land on the **integration branch** for this business user story — not on `develop` or a stray `feature/*` branch:

- Branch `integration/<business-ref>-<slug>` from up-to-date `develop` (create it if absent). Name it after the **business user story** from the business backlog (its reference + a slug) — you're at the grilling step, *before* `/to-spec`, so the branch is NOT named after the spec/technical ticket (it doesn't exist yet). See `docs/agents/business-backlog.md` for where the business backlog lives.
- The grilling output lands here. `/to-spec` then synthesises the spec; `/to-tickets` pushes this branch and bases the sub-tickets on it; `ready-for-agent` sub-tickets auto-merge back into the integration branch (after a green local check), and the `integration -> develop` merge stays human.

See the `git-flow` skill for the full integration-branch workflow.

## What each support skill carries

- **grilling** — the interview method: map the plan as a design tree, work the frontier in rounds, ask one round at a time with a recommended answer per question, and dispatch a subagent (if available) to find facts rather than asking for them.
- **domain-modeling** — the writing discipline: challenge terms against the glossary, sharpen fuzzy language, stress-test relationships with concrete scenarios, cross-check claims against the code, and write `CONTEXT.md`/ADRs inline as decisions land. It uses the formats in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md) and [ADR-FORMAT.md](./ADR-FORMAT.md).

## This session is a writer

Two grilling sessions are the **only writers** of `CONTEXT.md` and the ADRs: **`build-factory` context mode** (the project-context bootstrap) and **`grill-with-docs`** (per story). That is their purpose — externalizing business context and technical decisions into one deliberate step. Every other flow (implementation, triage, review) **reads** them and routes any discovered correction back to a grilling session via the ticket/PR — with the measurements (see `build-factory/domain.md`, *Read, don't write*).

## CONTEXT.md stays devoid of implementation

`CONTEXT.md` is a glossary and nothing else — never a spec, a scratch pad, a changelog, or a home for implementation decisions. An entry that needs the full contract points to the ADR that fixed it; it never inlines the contract. If a session leaves material that fits neither the glossary nor an ADR (implementation plans, case matrices, test inventories), it belongs in the ticket/PR that will implement it. Write entries with the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

## Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).

An ADR captures the decision, its why, and the measurements that killed the alternatives — never the implementation plan that follows (see *What stays out* in ADR-FORMAT.md). When a decision revises an earlier ADR, rewrite that ADR's body so it reads true today (see *Amending an ADR*) — never stack a dated addendum on a body that has become wrong.

## Next step

When shared understanding is reached and the docs are written, signpost the next step: `/to-spec` to synthesise the spec on the technical backlog from this grilling output. Guided, not gated — name the step, don't force it.

</supporting-info>
