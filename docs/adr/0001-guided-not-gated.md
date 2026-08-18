# Guided, not gated

PDSF keeps the user oriented instead of enforcing its pipeline. Every `/command` closes by
reporting what was just done and what the sensible next step is, backed by one small **workflow
map** kept in the always-in-context method constants so any skill can self-locate from the repo
state. Nothing is ever blocked — the compliant path is made the obvious path, never the only one.

## Considered Options

**Hard gates** — protected `main`/`develop` as an enforcement backbone, `/build-factory`
refusing to hand off until the wiring is verified, the green-FP auto-merge condition generalised
into a bypass block. Rejected on two grounds: advisory prompt-skills cannot truly enforce a
workflow anyway (any agent can ignore a `.md`), so the "guarantee" would be illusory; and gating
trades away the flexibility that expert-in-the-loop work depends on. Signposting delivers the
"never in the dark / dumb-friendly" benefit without the rigidity.
