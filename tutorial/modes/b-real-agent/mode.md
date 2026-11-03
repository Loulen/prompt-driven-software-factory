---
title: Real agent
summary: Your own agent runs the real PDSF skills, guided by /pdsf-tutorial. Spends tokens.
---

# Mode B — real agent

Nothing is simulated. After the setup, `play.sh` copies the **guide skill** `pdsf-tutorial` into
the workspace, and only there (ADR-0006). It then tells the learner to start their harness in the
workspace and type `/pdsf-tutorial`. The guide follows the scenario as its lesson plan. For each
step it explains what the learner does and what happens under the hood, has the learner type the
**real** PDSF command, runs the step's check, then moves on. Chapter 2 goes up to `/implement` of
one ticket of `Belt US-1`. Chapters 2 and 3 can be skipped.

This mode spends tokens. Chapter 1 is one grilling session plus two short skill runs. Chapter 2
adds a grilling, a spec, a ticket cut and a full `/implement` (TDD, review, agentic tests): count
on it costing several times chapter 1.

## What `play.sh` does

1. Narrates the install (already done by `tutorial.sh`) and re-runs its check, while the PDSF
   source is still there.
2. Copies the guide into `.agents/skills/pdsf-tutorial/`, the folder every harness layout reads
   (with the Claude layout, `.claude/skills` is a symlink to it). With the guide go the lesson plan
   it follows: `scenario/` (without the `recording/` slots, since nothing is replayed here) and
   `lib/`. The PDSF source is deleted when `tutorial.sh` exits, so the guide needs its own copy.
3. Writes the learner's answers (`PDSF_TUTO_HARNESS`, `PDSF_TUTO_SKIP_CH2/3`) to the guide's
   `tutorial.env`.
4. Adds `/.agents/skills/pdsf-tutorial/` to the workspace's `.git/info/exclude`. The guide is a
   tutorial file, not part of the factory: it never shows up in `git status` and is never
   committed with the learner's work. The working tree stays clean.
5. Prints how to start the harness and invoke the guide, then exits 0.

It reads no variable of its own.

## The guide skill (`pdsf-tutorial/`)

- `SKILL.md`: the guide's instructions. It is a portable skill (ADR-0002): plain markdown, no
  harness-specific tool or output style. It reaches the scenario only through `tuto.sh`.
- `tuto.sh`: the guide's only interface to the scenario. Run as `sh .agents/skills/pdsf-tutorial/tuto.sh <command>`:

  | Command | Does |
  | --- | --- |
  | `plan` | Every chapter and step, with its kind, its command, done (`[x]`) or not, and the skipped chapters |
  | `next` | The id of the next step to play (first not done, in a chapter not skipped), or `done` |
  | `chapter N` | Chapter N's title and introduction |
  | `show STEP` | The step's title, kind, command, `What you do` and `Under the hood` |
  | `action STEP` | Runs the step's deterministic action, if it has one |
  | `check STEP` | Runs the step's check in the workspace and records the step as done when it passes. The `setup` step was checked by `tutorial.sh`; it is only recorded here |
  | `skip N y\|n` | Skip (or un-skip) a skippable chapter |

  `STEP` is a step id (`01-build-the-factory/02-scaffold`) or its short form `1.2`. Progress is
  kept in the guide's `.progress` file, so `/pdsf-tutorial` resumes where it stopped.

## Running it from a shared PDO instance (optional)

A facilitator can run this mode for participants who have no harness subscription, from a shared
PDO instance. The recipe is in [`../../README.md`](../../README.md#mode-b-from-a-shared-pdo-instance-optional).
It is optional and needs no change in PDO.
