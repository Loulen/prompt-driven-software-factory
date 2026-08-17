# The project-context bootstrap is a build-factory mode, not a grilling session

`build-factory` has **two modes**:

- **Scaffold** — wire the backlogs, triage, and domain, and lay down `CLAUDE.md`, an empty
  `CONTEXT.md`, and `docs/adr/`.
- **Context** — the bootstrap: fill `CONTEXT.md`'s glossary and the foundational ADRs, reusing the
  `grilling` and `domain-modeling` support skills.

The *first* grilling of a project is this context bootstrap — an end in itself, with no business
story and no integration branch — so it belongs to `build-factory`, which owns setup.
`grill-with-docs` stays purely **per-story** (it always opens on an `integration/*` branch). The
writers of `CONTEXT.md`/ADRs are therefore *both* grilling sessions: `build-factory` context mode
and `grill-with-docs`.

## Considered Options

- **Make the bootstrap a "no-story mode" of `grill-with-docs`.** Rejected: it forces
  `grill-with-docs` to special-case the absence of a story and of an integration branch, muddying a
  skill that is otherwise cleanly per-story. Setup belongs with the setup skill.

## Consequences

`/verify-factory` checks both setup outputs (scaffold present, context filled). The bootstrap's
output — the baseline `CONTEXT.md` + foundational ADRs — lands on `develop` so every later
`integration/*` branch inherits it.
