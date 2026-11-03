---
title: Narrated replay
summary: Zero tokens, nothing to install: read along, step by step. Agent steps replay a recorded real run, flagged SIMULATED.
---

# Mode A1 — narrated replay

The learner walks the three chapters in the terminal and reads. No agent runs, no token is spent:
nothing beyond `sh`, `git` and `node` is needed.

For every step, in order:

1. the step's title, its kind, and **the exact command the learner would type** in their harness
   (`> /build-factory`; for the install, the `curl … | sh` line);
2. the learner text, **What you do** then **Under the hood**;
3. the step's deterministic action, if any, **run for real** (e.g. showing the business story);
4. for an `agent` step, the **simulated** part, inside a frame headed `SIMULATED`:
   - the replay of the recorded session (`recording/transcript.md`): what the learner typed, what
     the agent did (`⏺ Tool(…)` lines) and said;
   - then the recorded files applied onto the workspace (`rec_apply`), and **what changed**, shown
     by real `git` commands: branch, commit, `--stat`;
5. the step's **check**, run for real on the workspace. A failing check stops the mode (exit 1).

`setup` steps (the install) were already run for real by `tutorial.sh`: the mode narrates them and
re-runs their check. Chapters 2 and 3 are skipped with `PDSF_TUTO_SKIP_CH2` / `PDSF_TUTO_SKIP_CH3`.

## Variables

No variable of its own. It reads `PDSF_TUTO_PAUSE` (`n`: never wait for Enter; with a tty, it
otherwise waits after each step and between the exchanges of a replayed session) and the
`PDSF_TUTO_SKIP_CH*` answers, like every mode.

Non-interactive (`PDSF_TUTO_MODE=a1 PDSF_TUTO_PAUSE=n PDSF_TUTO_SKIP_CH2=n PDSF_TUTO_SKIP_CH3=n`),
it plays every step and every check: that run is the tutorial's regression test
(`tutorial/test/run.sh`).
