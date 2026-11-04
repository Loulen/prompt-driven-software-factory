# Blackbelt (lite)

**Grow belt by belt.** Blackbelt is where consultants make their skills visible and keep them
growing: in each **discipline** (Software Craftsmanship, Cloud & DevOps, Data Engineering,
Agility…), a consultant climbs the belts one colour at a time —
**WHITE → ORANGE → GREEN → BLUE → BROWN → BLACK** — coached by a **mentor**, until a **sensei**
validates the belt.

No exam, no certificate mill: each belt is a handful of concrete **objectives** the mentor sets with
the consultant ("pair-program a kata with TDD", "run a refactoring workshop"…). The mentor validates
them one by one, as they happen in real work.

## How a belt goes

```
REQUESTED → MENTOR_ASSIGNED → IN_PROGRESS → NEED_VALIDATION → VALIDATED / REFUSED
```

1. A consultant **requests** the next belt in a discipline (WHITE first, then the colour after their
   highest validated one; one open belt per discipline at a time).
2. A **mentor** is assigned (never the consultant themself).
3. The mentor adds the belt's **objectives** — the first one starts the belt (`IN_PROGRESS`) — and
   **validates** them as the consultant achieves them.
4. The consultant **submits** the belt for the sensei's validation (`NEED_VALIDATION`) — *not built
   yet: see the business backlog.*
5. The **sensei** validates or refuses the belt.

## Try it

Node 18+ only — no `npm install`, no dependency.

```sh
node src/cli.js list                       # every belt
node src/cli.js show B-2                   # a belt and its objectives
node src/cli.js request ada cloud          # Ada requests her first Cloud & DevOps belt
node src/cli.js assign-mentor B-5 margaret
node src/cli.js add-objective B-5 margaret Deploy a container to a managed service
node src/cli.js validate-objective B-5 1 margaret
node src/cli.js reset                      # back to the seed data
node --test                                # the test suite
```

The CLI keeps its state in `.blackbelt-state.json` (git-ignored), initialised from `data/seed.json`.

## Layout

| Path | What |
| --- | --- |
| `src/belts.js` | Belt colours and their order |
| `src/workflow.js` | Belt statuses and allowed transitions |
| `src/blackbelt.js` | The domain: requests, mentors, objectives, the sensei's decision |
| `src/store.js`, `src/cli.js` | Local JSON state and the CLI over the domain |
| `data/seed.json` | Seed disciplines, people and belts |
| `test/` | `node --test` suite |
| `business-backlog/` | The business backlog: user stories, one markdown file each |
