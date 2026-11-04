<!-- PDSF:BEGIN -->
## PDSF skills

The PDSF skills are installed under `.agents/skills/` (also reachable as `.claude/skills/`). Invoke
any of them as `/<skill>` (e.g. `/grill-with-docs`) — your harness loads the skill's markdown into
context on demand.

## Agentic tests (concept)

Apex of the pyramid: a subagent drives the **real running system** through its **primary
surface** — the UI for a web app, the cloud CLI for infra, the warehouse for a data pipeline —
along a journey, probing internals only when the surface isn't enough. It sits **above
end-to-end tests**: the QA pass, performed by an agent instead of a human. Two levels:

- **Happy Path (HP)**: curated suite (**at most 3 HP**), core value, under
  `docs/test-scenarios/`. Run + reported at the **integration→develop** MR (human decision).
- **Feature Path (FP)**: **executable** acceptance criteria of a ticket (in the ticket body,
  **throwaway**). Ticket→integration **auto-merge** gate: green FP + no blocking finding, on
  top of build + tests.

Runner: `/agentic-tests`. Format & inventory: the `agentic-tests` skill's `SCENARIO-FORMAT.md`.

## Dev workflow

For a `ready-for-agent` ticket: branch per Git flow, then run **`/implement`** — the three-role
loop. It drives `/tdd` (red → green at the agreed seams) on the lower pyramid tiers, an
**independent** `/code-review` on the diff, and a subagent that runs `/agentic-tests` on the
ticket's Feature Path — driving the running system through its **primary surface** and reporting
findings, so validation is an actual step, not just a suggestion. It iterates until build + tests
+ FP are green with no blocking finding, then merges per Git flow. Refactoring belongs to the
review stage, not the red → green cycle.

Subagents are the **baseline** — `/implement` uses them where available and degrades to a
sequential `/tdd → /code-review → /agentic-tests` run otherwise. Building richer orchestrations on
top (parallel/adversarial reviewers, several FPs, dedicated workflow tooling) is encouraged.

## Git flow

Simplified vanilla git flow (`main`/`develop`/`integration/*`/`feature/*`/`hotfix/*`, no
`release` until pre-prod). Every instance must know it:

@.agents/skills/git-flow/SKILL.md

## Agent skills

### Business backlog
Local markdown, one story per file in `business-backlog/`; agents pick `Status: Ready`. See `docs/agents/business-backlog.md`.

### Technical backlog (issue tracker)
Local markdown under `.scratch/<feature-slug>/` (`SPEC.md` + `tickets/NN-<slug>.md`). See `docs/agents/issue-tracker.md`.

### Triage labels
The five default role names, as a `Status:` line in each ticket. See `docs/agents/triage-labels.md`.

### Domain docs
Single-context: `CONTEXT.md` + `docs/adr/` at the root. See `docs/agents/domain.md`.

### User-story layout
Default layout for business user stories. See `docs/agents/us-format.md`.
<!-- PDSF:END -->
