# Monorepo: a self-contained factory per business context

In a monorepo, each **business context** gets a self-contained factory at `.factory/<context>/` —
its own copy of the skills, plus the shared domain docs (`CONTEXT.md`, `docs/adr/`, `docs/agents/`)
and method constants (`AGENTS.md`) for that context. A context's sub-projects are wired to it by
per-skill **relative** symlinks into their `.claude/skills/` and a relative pointer from their
`AGENTS.md`; they share the context's skills and domain.

**Nothing is installed or loaded at the monorepo root** — opening the root never drags a context's
skills into context, and unrelated sub-projects stay untouched. The **only** artifact shared across
the whole monorepo is `.factory/pdsf-install.sh`: the re-runnable tool that creates a
(user-named) factory or wires one or more sub-folders into a selected one. It discovers existing
factories by listing `.factory/*/`, so there is no registry file.

## Considered Options

- **One shared skills copy for the whole monorepo.** Rejected: it couples every context to a single
  skill version for little gain, since skills are generic. Per-context duplication is accepted
  deliberately — each factory stays independently versionable and self-contained, and the real
  problem (uncontrolled per-*sub-project* vendoring) is already solved by sharing at the context
  level.
- **A `CONTEXT-MAP.md` registry inside `.factory/`.** Rejected as redundant with the directory
  listing. (`CONTEXT-MAP.md` at the repo root remains the *single-repo* multi-context mechanism — a
  different topology.)
- **A parent grouping folder or root-level wiring.** Rejected: touches CI and violates the
  no-root-loading guard.

## Consequences

Relative symlinks plus a rule that `.factory/` is **never sparse-excluded** prevent the factory from
silently vanishing (a dangling link on sparse-checkout, or on Windows without symlinks). Windows
without symlinks stays an open limitation for a later pass.
