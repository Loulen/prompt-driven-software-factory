---
title: Simulated session
summary: Zero tokens: make the real gestures. Type `claude`, the real slash commands and your answers, in a sub-shell where a stand-in claude replays a recorded real run.
---

# Mode A2 — simulated session

The learner makes the gestures they will make on their project, without spending a token. For the
agent steps, they type `claude` in a terminal, then the real slash commands, and answer the agent's
questions. The `claude` they talk to is a **stand-in** that replays the recordings of mode A1
(`tutorial/scenario/*/*/recording/`). Only `sh`, `git` and `node` are needed.

## How it plays

The chapters are played in order. As in mode A1, the install (`setup`) is narrated and re-checked,
and `reading` steps show their text, run their action for real, then their check.

A chapter's consecutive **agent steps** are played in one **simulated session**:

1. The tutorial lists the commands to type and opens a **sub-shell** in the workspace, framed
   `┌─ SIMULATED SESSION ─`. Its prompt starts with `(pdsf simulated)`. It is the learner's own
   shell (`$SHELL`: bash, zsh or a POSIX sh), with their rc file. After that rc file, a temporary
   directory is put first on `PATH`; it holds the stand-in `claude`. That directory exists only for
   the duration of the mode, outside the workspace, and no other shell has it on its `PATH`. **The
   learner's real `claude` is untouched.** Everything else in the sub-shell is real (`git log`,
   `ls`, `node --test`…).
2. `claude` (the stand-in) opens with a banner saying it is simulated, then shows the next step:
   its command, **What you do**, **Under the hood**, and its deterministic action, run for real.
   The learner types the step's slash command. Arguments are accepted, and the recorded form is
   shown when it differs.
3. The recorded session is replayed in a `┌─ SIMULATED ─` frame. The stand-in shows the agent's
   turns, and asks each recorded question as **numbered choices**: `1` is the recorded answer,
   the default on Enter, then the recorded alternatives (`pdsf-choices`). The learner can also type
   their own answer. **Any answer but the recorded one is accepted and flagged**: `⚑ off-script —
   simulated: a real agent would adapt, the recorded path continues.` The recorded answer is shown,
   and the recorded agent turns go on.
4. At the end of the step, the stand-in applies the recorded files **exactly as A1 does**
   (`rec_apply`), shows what changed (real `git` output), then shows the next step's text.
5. **A command that is not recorded at this step** gets `simulated session: not recorded`, plus
   the command available at this step, `/help` and `/exit`. A recorded command typed out of order
   gets the same reply, and is said to be already played or recorded for a later step. So does free
   text at the prompt.
6. `/exit` (or `exit`, Ctrl-D, Ctrl-C) leaves the stand-in. A step left halfway applies nothing:
   typing `claude` again resumes at that step. A step recorded in the **same agent session** as the
   previous one (`session: continued`, e.g. `/to-spec` after the grilling) says so. If the learner
   restarted `claude` in between, the stand-in also says that a real agent would lack the context.
7. Leaving the sub-shell (`exit`, Ctrl-D) returns to the tutorial. If steps are left, it offers to
   re-open the session (`o`), replay them for the learner as mode A1 does (`r`), or stop (`q`). Then
   it **runs the check of each step of the session, for real**. A failing check stops the mode
   (exit 1).

Same recordings and same `rec_apply` as mode A1: after each chapter, the workspace is in the
**same state as with A1** (same files, branches and commit messages). The step checks judge it.
The rendering is A1's (`lib/replay.sh`).

## Variables

Like every mode, it reads `PDSF_TUTO_PAUSE` and the `PDSF_TUTO_SKIP_CH*` answers. Its own variables
follow the tutorial's set/unset rule: a **set** variable answers without asking, even empty.

| Variable | Meaning | Default |
| --- | --- | --- |
| `PDSF_TUTO_A2_SESSION` | A file of shell commands, run with `sh` **in place of the interactive sub-shell**, with the same `PATH` (stand-in first) and `PDSF_TUTO_A2_CHAPTER=<n>`. It types for the learner, e.g. `printf '%s\n' /build-factory 2 '' … /exit \| claude`. **Empty**: the recorded path (below), even with a terminal. | the interactive sub-shell; with no terminal, the recorded path |
| `PDSF_TUTO_A2_LEFT` | What to do with the steps left after the sub-shell: `o` re-open it, `r` replay them for you, `q` stop. Without a terminal, `o` falls back to `r`. | `o` with a terminal, `r` without |

**The recorded path**, used with no terminal or with `PDSF_TUTO_A2_SESSION=` (empty), types into
one `claude` each pending step's recorded command, Enter at each question, then `/exit`. So
`PDSF_TUTO_MODE=a2 PDSF_TUTO_PAUSE=n PDSF_TUTO_SKIP_CH2=n PDSF_TUTO_SKIP_CH3=n` plays the whole
tutorial non-interactively, with zero tokens. It is tested against mode A1's end state in
`tutorial/test/run.sh`.
