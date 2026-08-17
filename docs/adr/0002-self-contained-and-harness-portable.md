# Self-contained and harness-portable

PDSF assumes **nothing** from the host harness. It vendors every skill it uses — including
`code-review` and the `grilling` engine — rather than borrowing whatever a harness happens to
ship, and skills are written **to capabilities, not to a named harness feature**: "a
slash-loadable skill", "subagents if available", "a running app to drive". Invocation is portable
because "slash loads a markdown prompt into context" exists nearly everywhere (Claude Code skills,
Copilot prompt files, Cursor commands).

Install is a first-party **`curl … | sh` bootstrap**: zero-dependency, install-**everything** (no
skill-subset selection), and it emits each skill into the target harness's slash location —
`.claude/skills/` (Claude Code), `.github/prompts/` (Copilot) — and wires `CLAUDE.md` and/or
`AGENTS.md`, via a **scoped shell emitter we control**. The bootstrap doubles as the resident
monorepo tool (see ADR-0003).

## Considered Options

- **Delegate emission to skills.sh / `npx skills`.** Rejected as the primary path: it is
  third-party (can't host our monorepo prompt or the connection validation), and it pulls in
  Node. Kept as a documented escape hatch for a harness we don't emit to.
- **Rely on host-provided skills** (e.g. Claude Code's built-in `/code-review`). Rejected: PDSF
  installs into arbitrary repos and harnesses and cannot assume any particular one is present.

## Consequences

The only capability that cannot be made portable is `implement`'s multi-subagent orchestration; it
degrades to a sequential `/tdd → /code-review → /agentic-tests` run where subagents are
unavailable.
