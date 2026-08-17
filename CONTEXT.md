# Prompt Driven Software Factory (PDSF)

An agentic software factory: a set of Claude Code skills (`/…` commands) plus a bootstrap skill
(`/build-factory`) that wire a clear process — from business need to deployment — into a repo.
This glossary is the language the factory's own skills and docs must speak.

## Language

### Backlogs

**Business backlog**:
Human-owned user stories — the "what" and "why", upstream of design.
_Avoid_: product backlog

**Technical backlog**:
Agent-owned, self-contained work items — the "how", produced by design and consumed by agents.

**Ticket**:
A self-contained, agent-grabbable unit of technical work on the technical backlog, produced by
`/to-tickets`. Its concrete backend may be a GitHub/GitLab issue or a local markdown file.

### Design & artifacts

**Grilling**:
A design session that resolves decisions one at a time and writes them down — the project-context
bootstrap (`build-factory` context mode) and per-story design (`grill-with-docs`). The grilling
sessions are the **only writers** of `CONTEXT.md` and the ADRs; every other flow only reads them.

**Spec**:
The synthesised requirements document produced by `/to-spec` on the technical backlog, bridging
grilling output into sliceable work.
_Avoid_: PRD

**Vertical slice**:
A thin path cut through every layer end-to-end, demoable on its own — the unit `/to-tickets`
produces.
_Avoid_: tracer bullet (same idea; prefer "vertical slice")

### Testing

**Agentic test**:
Apex of the test pyramid: a subagent drives the **real running system** through its **primary
surface** — the UI for a web app, the cloud CLI for infra, the warehouse for a data pipeline —
along a journey, probing internals only when the surface isn't enough. It sits **above
end-to-end tests** — the QA pass, performed by an agent instead of a human.

**Feature Path (FP)**:
The executable nominal journey carried by a ticket; the sub-ticket → integration auto-merge gate.
Throwaway — it lives and dies with the ticket.

**Happy Path (HP)**:
A curated, cross-cutting journey (**at most 3**) under `docs/test-scenarios/`, run and reported at
the integration → develop merge.

### Branching

**Integration branch**:
`integration/<business-ref>-<slug>`, one per business story, named after the business item. Holds
the grilling output and accumulates the story's sub-tickets before a human merge to `develop`.

### Context layout

**Context**:
A bounded domain with its own `CONTEXT.md` + ADRs. Most repos have one.

**Context map**:
`CONTEXT-MAP.md` at the repo root — the *single-repo* multi-context mechanism; it lists each
context and how they relate. (A monorepo uses factories instead; see below.)

**Factory**:
A self-contained install of PDSF — skills + domain docs + wiring — for one context. In a monorepo
it lives at `.factory/<context>/`, shared by that context's sub-projects. See ADR-0003.

**Member sub-project**:
A monorepo sub-project wired to a factory by relative symlinks; it shares that factory's skills and
domain, and loads nothing at the monorepo root.

## Principles

**Guided, not gated**:
The factory keeps the user oriented rather than enforcing its pipeline — self-aware of the current
phase, always signposting the next step, never blocking. See ADR-0001.

**Expert in the loop**:
The human supervises as a domain/technical expert concentrated in design and validation, not as a
step-by-step operator of the agents.
