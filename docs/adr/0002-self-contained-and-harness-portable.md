# Self-contained and harness-portable

PDSF assumes **nothing** from the host harness. It vendors every skill it uses — including
`code-review` and the `grilling` engine — rather than borrowing whatever a harness happens to
ship, and skills are written **to capabilities, not to a named harness feature**: "a
slash-loadable skill", "subagents if available", "a running app to drive". Invocation is portable
because "slash loads a markdown prompt into context" exists nearly everywhere (Claude Code skills,
Cursor commands, an `AGENTS.md` any harness reads).

Install is a first-party **`curl … | sh` bootstrap**: zero-dependency, install-**everything** (no
skill-subset selection), via a **scoped shell emitter we control**. The base install is **generic**:
regular skill folders under `.agents/skills/` plus a wired `AGENTS.md` — the cross-harness standard
that Copilot, Cursor, and Codex already read, so one emitter serves them all. **Claude support is a
symlink overlay on top of that base** (`.claude/skills → .agents/skills`, `CLAUDE.md → AGENTS.md`),
never a second emitter. The bootstrap doubles as the resident monorepo tool (see ADR-0003).

## Considered Options

- **A Copilot-specific emitter** (`.github/prompts/<skill>.prompt.md`, flattened). Rejected: it
  forks the emitter per harness and strips a skill's supporting files down to a single flat prompt.
  The generic `AGENTS.md` + regular skills already covers Copilot and most harnesses; Claude is the
  only harness that earns anything extra, and that extra is just symlinks.
- **Delegate emission to skills.sh / `npx skills`.** Rejected as the primary path: it is
  third-party (can't host our monorepo prompt or the connection validation), and it pulls in
  Node. Kept as a documented escape hatch for a harness with unusual conventions.
- **Rely on host-provided skills** (e.g. Claude Code's built-in `/code-review`). Rejected: PDSF
  installs into arbitrary repos and harnesses and cannot assume any particular one is present.

## Consequences

The only capability that cannot be made portable is `implement`'s multi-subagent orchestration; it
degrades to a sequential `/tdd → /code-review → /agentic-tests` run where subagents are
unavailable.
