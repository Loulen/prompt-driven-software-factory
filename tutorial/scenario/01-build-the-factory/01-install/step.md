---
title: Install PDSF into the workspace
kind: setup
command: curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/install.sh | sh
---

## What you do

You run the PDSF installer in your project, and answer one question: the **harness layout**.

- `[1] .agents` — the generic layout: every skill under `.agents/skills/`, plus an `AGENTS.md`
  that points your agent at them. Copilot, Cursor, Codex and Claude Code all read it.
- `[2] .agents + .claude symlinks` — the same, plus a thin overlay of symlinks so Claude Code
  finds its own paths: `.claude/skills -> .agents/skills` and `CLAUDE.md -> AGENTS.md`.

In this tutorial, the entry script ran the real `install.sh` for you, with your answer, and
committed the result.

## Under the hood

`install.sh` copies **every** PDSF skill (one folder with a `SKILL.md` each) into
`.agents/skills/`, and writes a marked block (`<!-- PDSF:BEGIN -->…<!-- PDSF:END -->`) into
`AGENTS.md`. The block can be rewritten on a re-run, never duplicated. The Claude option adds
**nothing but symlinks**: one copy of the skills, two ways to find them.

A skill is plain markdown: typing `/build-factory` loads `.agents/skills/build-factory/SKILL.md`
into the agent's context. No server, no plugin. On your project, every prompt of the installer can
also be answered with a `PDSF_*` variable (`PDSF_HARNESS=generic|claude`, see `docs/INSTALL.md`).
