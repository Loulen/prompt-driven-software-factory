# PDSF Tutorial

Discover PDSF and build your first factory, step by step, on a throwaway **tutorial workspace**
seeded from the **tutorial fixture** `blackbelt-lite`. The tutorial ships with PDSF but is not a
skill: `install.sh` never installs any of it into a project (ADR-0006).

```sh
curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
```

Offline, from a local checkout (run it from the directory that will hold the workspace, outside
the checkout):

```sh
PDSF_SRC=/path/to/pdsf sh /path/to/pdsf/tutorial/tutorial.sh
```

Needs `sh`, `git`, and Node 18+ (the fixture's tests run with plain `node --test`, no `npm install`).

## What it does

1. **Resolves a PDSF source**: `PDSF_SRC`, else `git clone --depth 1` into a temp dir, else the
   tarball (removed at exit). It never writes into that source.
2. **Creates the workspace**: default `./pdsf-tutorial-workspace`. It refuses a non-empty directory
   and any directory inside the PDSF source. It copies the fixture, then `git init` + an initial
   commit on `main`.
3. **Explains the harness layout and asks for it**: `[1] .agents` (generic) or
   `[2] .agents + .claude symlinks` (default). Then it runs the real `install.sh` from the resolved
   source, commits the install, creates `develop` and checks it out. Then it runs the install
   step's check.
4. **Offers the tutorial modes**: only the ones actually shipped under `modes/`. With none shipped,
   it says so and exits cleanly (status 0) after the setup. Shipped: **A1, narrated replay**
   (`modes/a1-narrated-replay/`, zero tokens: agent steps replayed from a recorded real run,
   flagged `SIMULATED`).
5. Plays the chosen mode, then ends on **where to look next**.

Three chapters:

1. **Build the factory**: install, `/build-factory` scaffold (local markdown tracker for both
   backlogs), `/build-factory` context, `/verify-factory`.
2. **Use the factory** (skippable): `Belt US-1 [user] Submit my belt for sensei validation` through
   `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement` of one ticket.
3. **Go further** (skippable): README and `docs/INSTALL.md`, `/verify-factory` as the "what's next"
   oracle, `/clean-context`, plugging PDO. PDSF and PDO are independent.

## Layout

```
tutorial/
├── tutorial.sh                 ← the entry script (curl … | sh)
├── lib/
│   ├── scenario.sh             ← scenario + modes library, sourced by tutorial.sh and every mode
│   ├── recording.sh            ← reads and replays the recordings (simulated modes, recorder)
│   └── check.sh                ← helpers for step checks
├── fixture/blackbelt-lite/     ← copied verbatim into the workspace
├── scenario/                   ← the lesson plan every mode plays, with its recordings (contract below)
├── modes/                      ← one folder per shipped tutorial mode (contract below)
│   └── a1-narrated-replay/     ← mode A1: narrated replay
├── record/                     ← the recorder: (re-)records the agent steps from a real run
└── test/run.sh                 ← the test suite
```

## Environment (`PDSF_TUTO_*`)

Same rule as `install.sh`: a **set** variable answers its question without prompting, **even when
empty**. An **unset** one is asked on `/dev/tty` (so `curl … | sh` stays interactive). With no tty,
the default is used. A fully non-interactive run sets them all.

| Variable | Meaning | Default |
| --- | --- | --- |
| `PDSF_TUTO_DIR` | Workspace directory (absent or empty, outside the PDSF source). | `./pdsf-tutorial-workspace` |
| `PDSF_TUTO_HARNESS` | Harness layout: `claude` / `2` (`.agents` + `.claude` symlinks) or `generic` / `1` (`.agents`). Passed to `install.sh` as `PDSF_HARNESS`; **modes receive it normalised** to `claude` or `generic`. | `claude` |
| `PDSF_TUTO_MODE` | Mode to play: its menu number, its id (`a1`) or its folder name (`a1-narrated-replay`). **Empty: stop after the setup.** Modes receive the resolved id. | first shipped mode |
| `PDSF_TUTO_SKIP_CH2` | `y` to skip chapter 2. Asked only when a mode is played; modes receive `y` or `n`. | `n` |
| `PDSF_TUTO_SKIP_CH3` | `y` to skip chapter 3. Same as above. | `n` |
| `PDSF_TUTO_PAUSE` | `n`: never wait for Enter between steps (`tuto_pause`). | `y` |
| `PDSF_SRC` | Local PDSF checkout to play from: fully offline. | (fetch) |
| `PDSF_REPO`, `PDSF_TARBALL` | Override the clone / tarball URLs. | public repo |

Set by the entry script for steps and modes (not for the learner to set):

| Variable | Value |
| --- | --- |
| `PDSF_TUTO_SRC` | The resolved PDSF source (its `install.sh`, `skills/`, `tutorial/`). |
| `PDSF_TUTO_ROOT` | `$PDSF_TUTO_SRC/tutorial`. |
| `PDSF_TUTO_WORKSPACE` | The workspace, absolute path. |

A mode that needs more answers (e.g. the simulated session's recorded choices) adds its own
`PDSF_TUTO_*` variable under the same set/unset rule and documents it in its `mode.md`.

## Scenario contract

The scenario is **data**, shared by every mode: one directory per step, ordered, grouped into
chapters. Ordering is the `NN-` prefix.

```
scenario/
└── 01-build-the-factory/       ← chapter: NN-<slug>/
    ├── chapter.md              ← frontmatter: title, skippable (true|false); body: chapter intro
    └── 02-scaffold/            ← step: NN-<slug>/
        ├── step.md             ← learner text (required)
        ├── action.sh           ← deterministic action (optional)
        ├── check.sh            ← check of the expected workspace state (required)
        └── recording/          ← recording slot (agent steps; see below)
```

A step is identified by `<chapter>/<step>`, e.g. `01-build-the-factory/02-scaffold`.

### `step.md`

```markdown
---
title: Scaffold the factory
kind: agent
command: /build-factory
---

## What you do

…what the learner types and answers…

## Under the hood

…what the skill reads and writes, and why; where a real project differs…
```

- `title`: one line.
- `kind`: what kind of work the step is.
  - `setup`: run **for real** by `tutorial.sh` before the mode menu (the install). Modes narrate it
    and may re-run its check; they never redo it.
  - `agent`: the work of a PDSF skill. In a simulated mode it is **replayed from a recording**, and
    always flagged as simulated to the learner. In the real-agent mode, the real skill does it.
  - `reading`: explanation only, no agent work. It may still have a deterministic action.
- `command`: what the learner types (the slash command, or the shell command for `setup`).
  Required for `agent` steps; optional otherwise.
- `## What you do` and `## Under the hood`: both required, plain English markdown, read verbatim
  by every mode (`tuto_section`).

### `action.sh` (optional)

A **deterministic** action that always runs for real, never simulated (e.g. the install, or
showing the seed story). Run as `sh action.sh` with the workspace as cwd and the `PDSF_TUTO_*`
environment above. Its output is shown to the learner. Non-zero = the action failed.

### `check.sh` (required)

Checks that the workspace reached the step's expected state, by observing files, git and the
fixture's tests, never by trusting a mode. Run as `sh check.sh` with the workspace as cwd and the
`PDSF_TUTO_*` environment. It sources `"$PDSF_TUTO_ROOT/lib/check.sh"`, prints one `✓` / `✗` line
per expectation, and ends with `check_done`: **exit 0 = the step succeeded**. Every mode runs it
after the step. A simulated step must leave the workspace in a state that passes it, exactly like
the real skill would.

Checks of `agent` steps fail on a workspace where the agent has not run yet. That is how the test
suite proves they actually check something.

### Recordings (`recording/`)

Every `agent` step has a `recording/` folder: the recording of a **real run** of the skill on a
fresh tutorial workspace (ADR-0006: never improvised output). The simulated modes replay it.
`tuto_has_recording STEP` is true once `transcript.md` exists.

```
recording/
├── transcript.md     ← the recorded session: metadata + every turn, learner and agent
└── files/            ← the files the run created or changed, as a tree applied verbatim
```

#### `transcript.md` (format 1)

Readable as plain markdown, and parsed by `lib/recording.sh` (`rec_*`). The frontmatter:

| Key | Meaning |
| --- | --- |
| `step` | The step id, `<chapter>/<step>`. |
| `command` | The step's `command`, as in its `step.md`. |
| `branch` | The branch the run ended on. The replay switches to it, creating it from `HEAD` if absent. |
| `commit` | The message of the replayed commit: the last commit the agent made (else the recorder's). |
| `session` | `new`, or `continued`: the step ran in the **previous step's agent session** (the learner typed the next command in the same session, e.g. `/to-spec` right after the grilling). |
| `via` | Optional. A branch the run created, committed on, then merged into `branch` (e.g. `/implement`'s `feature/*`). The replay commits there and merges it back `--no-ff`. |
| `merge` | The message of that merge commit. |
| `branches` | Other branches the run created (space-separated); the replay creates them at the end. |
| `removed` | Paths the run deleted (space-separated). |
| `recorded`, `recorder`, `pdsf`, `harness` | When, with which agent (`Claude Code <version>, <model>`), from which PDSF commit, on which harness layout. |
| `format` | `1`. |

Then a short header, then the **turns**, in order. Each turn starts with a marker line, then a
cosmetic heading:

```markdown
<!-- pdsf-turn: learner -->
### You

/build-factory

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git remote -v; ls -la; …)

Here's what's in the repo now: … **Where does your business backlog live?**

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Jira | Notion | To define later -->
### You

Keep the local markdown folder business-backlog/: one story per file, that's our business backlog.
```

- Turns alternate, the **learner first** (the command as typed, possibly with an argument, e.g.
  `/grill-with-docs business-backlog/BELT-US-1-….md`) and the **agent last**.
- A **learner turn** is the recorded answer. Its optional `pdsf-choices` line holds the
  **alternative** answers to that question (`|`-separated), not including the recorded one: the
  simulated session (A2) offers them as numbered choices, the recorded answer being the default.
- An **agent turn** is what the learner would see in their harness: the agent's text, and one
  `⏺ Tool(target)` line per tool call, in order. Subagent traffic is left out. Paths are relative
  to the workspace.
- A turn's text is everything up to the next marker (`rec_turn_text`), so the agent's own `###`
  headings are safe. `rec_turn_count`, `rec_turn_role`, `rec_turn_choices` read the rest.

#### The replay (`rec_apply`)

`rec_apply STEP` puts the workspace in the state the real run left it in: it switches to `branch`
(and to `via`, if any), copies `files/` over the workspace, deletes `removed`, commits those paths
with `commit`, merges `via` back, and creates `branches`. Each step's check then judges the result.
The real run's own commits are squashed into one per step (plus the merge).

Recordings are made on the `claude` harness layout (the recording agent is Claude Code). Replayed
on a generic workspace, the only trace is one mention of `.claude/skills/` in the replayed
`AGENTS.md`.

#### Re-recording (maintainers)

The recordings drift when the skills change. `sh tutorial/test/run.sh` replays them all and runs
every step check: the drift guard. To regenerate them, use the recorder, `tutorial/record/record.sh`.
It spends tokens. It drives a real, non-interactive Claude Code session in a tutorial workspace:
one `claude -p` call per learner turn, `--resume` in between, `--permission-mode
bypassPermissions` (the workspace is a throwaway). Needs `claude`, logged in, and `node`.

```sh
R=tutorial/record/record.sh
sh $R steps                               # the agent steps, in order

# Re-record everything with the recorded answers (each step continues from the previous one):
sh $R all /tmp/rec-ws

# Re-record one step, adapting the answers to what the agent now asks:
sh $R prepare 02-use-the-factory/01-grill-with-docs /tmp/rec-ws   # setup for real, earlier steps replayed
sh $R turn /tmp/rec-ws "/grill-with-docs business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md"
sh $R turn /tmp/rec-ws --choices "All ok, but write an ADR | 1 (b), the rest ok" "All ok."
# … one `turn` per answer, reading each question first …
sh $R finish 02-use-the-factory/01-grill-with-docs /tmp/rec-ws      # writes the recording, runs the check
# The next step continues in the same agent session when it did before (session: continued):
sh $R turn /tmp/rec-ws --continue /to-spec
```

- `run STEP WS` replays the learner turns of the current `transcript.md` against the real agent,
  then `finish`es. Use it when the questions did not change. Edit the learner turns first to steer.
- `finish` commits whatever the agent left uncommitted (so the next step starts from the same
  state), copies every path changed since the step started into `files/`, writes
  `transcript.md`, and **runs the step's check**: a recording that fails its check is rejected.
- Answer as the domain expert would: the fixture's README and the story `Belt US-1` are the source
  of truth. Keep the alternatives (`--choices`) plausible: they are what A2 offers.
- A step depends on the previous ones: after re-recording step N, re-record (or at least re-run
  the tests on) the steps after it. Then run `sh tutorial/test/run.sh` and review the diff of
  `scenario/*/*/recording/`.
- `PDSF_RECORD_MODEL` passes `--model`; `PDSF_RECORD_CLAUDE` replaces the agent command (the test
  suite uses a fake one).

## Modes contract

A shipped mode is a folder `modes/<id>-<slug>/` holding:

- `mode.md`, with frontmatter `title:` and `summary:` (one line each, shown in the menu). The body
  is free documentation (the mode's own variables, how it plays the steps).
- `play.sh`, the mode's entry point.

A folder without both files is not shipped and is not offered. The menu lists shipped modes in
folder-name order. Planned ids: `a1` (narrated replay, **shipped**), `a2` (simulated session), `b`
(real agent).

`tutorial.sh` runs `sh modes/<id>-<slug>/play.sh` **after the setup**:

- cwd = the workspace; stdin = `/dev/tty` when there is one (else `/dev/null`); stdout/stderr =
  the learner's terminal;
- environment = every `PDSF_TUTO_*` variable above (`PDSF_TUTO_MODE` = the resolved id,
  `PDSF_TUTO_HARNESS` normalised, `PDSF_TUTO_SKIP_CH2/3` = `y`|`n`, `PDSF_TUTO_PAUSE`);
- the mode plays the chapters in order: for each one not skipped (`tuto_chapter_skipped`), it plays
  each step: shows the title and command, the learner text, runs the action
  (`tuto_run_action`), does or replays the agent work, then runs the check (`tuto_run_check`);
- its exit status becomes the tutorial's. Then `tutorial.sh` prints "where to look next".

The resolved PDSF source is removed when `tutorial.sh` exits (when it was fetched): a mode that
needs files after its run copies them into the workspace. That is how the real-agent mode's guide
skill gets **only** into the workspace, never into `skills/` (ADR-0006).

## Libraries (`lib/scenario.sh`, `lib/recording.sh`)

Source it after exporting `PDSF_TUTO_ROOT`:

| Function | Does |
| --- | --- |
| `tuto_chapters` / `tuto_steps CHAPTER` | List chapter / step directories, in order |
| `tuto_meta FILE KEY`, `tuto_body FILE`, `tuto_section FILE "Heading"` | Read a frontmatter value, the body, a `## Heading` section |
| `tuto_step_title` / `tuto_step_kind` / `tuto_step_command STEP`, `tuto_step_id STEP` | Step metadata |
| `tuto_chapter_number CHAPTER`, `tuto_chapter_skipped CHAPTER` | Chapter number; skippable and skipped by `PDSF_TUTO_SKIP_CH<n>` |
| `tuto_has_action` / `tuto_run_action STEP` | The deterministic action, run in the workspace |
| `tuto_run_check STEP` | The step's check, run in the workspace; its status is the verdict |
| `tuto_has_recording STEP` | A recording is in the slot |
| `tuto_modes`, `tuto_mode_id MODE` | Shipped modes; a mode's short id |
| `tuto_ask VAR "prompt" default`, `tuto_pause`, `tuto_is_yes`, `tuto_is_no` | Prompts on `/dev/tty`, env-overridable |
| `tuto_say`, `tuto_bold`, `tuto_dim`, `tuto_rule`, `tuto_die` | Terminal output |
| `tuto_width`, `tuto_md WIDTH [PREFIX]` | The render width; markdown on stdin, re-flowed and wrapped for the terminal |

`lib/recording.sh` (source it after `lib/scenario.sh`):

| Function | Does |
| --- | --- |
| `rec_meta STEP KEY` | A frontmatter value of the step's `transcript.md` |
| `rec_turn_count` / `rec_turn_role` / `rec_turn_text` / `rec_turn_choices STEP [N]` | The turns: how many, `learner`/`agent`, text, alternative answers |
| `rec_files STEP` | The recorded files, workspace-relative |
| `rec_apply STEP` | Replay the recorded end state onto the workspace (see § The replay) |
| `rec_git ARGS…` | git in the workspace, with a fallback identity |

## The fixture: `blackbelt-lite`

A small, public-safe, **from-scratch** rewrite of the Blackbelt domain. Nothing is copied from
Ippon's internal Blackbelt repositories. It is in English, uses JavaScript ES modules, and has no
npm dependency. It covers disciplines, belt colours WHITE → ORANGE → GREEN → BLUE → BROWN → BLACK,
belt requests, mentor assignment, objectives validated by the mentor, the sensei's decision, and
the workflow `REQUESTED → MENTOR_ASSIGNED → IN_PROGRESS → NEED_VALIDATION → VALIDATED / REFUSED`.
A tiny CLI (`node src/cli.js list | show | request | assign-mentor | add-objective |
validate-objective | decide | reset`) drives it. See its README.

Its business backlog is the local markdown folder `business-backlog/`, one story per file. It is
seeded with `Belt US-1 [user] Submit my belt for sensei validation`, which is **not** implemented.
Chapter 2 implements it. Point the scaffold's business backlog at that folder.

## Tests

```sh
sh tutorial/test/run.sh                          # the tutorial, played non-interactively
(cd tutorial/fixture/blackbelt-lite && node --test)  # the fixture's own tests
```

The suite plays `tutorial.sh` against this checkout (`PDSF_SRC`) in temp dirs and asserts:

- both harness layouts, piped and file invocation;
- refusals: a non-empty workspace, a workspace inside the source;
- the mode menu and its dispatch contract, using fake modes in a copy of the source;
- the scenario's shape, and that the checks really discriminate;
- the `install.sh` contract: no tutorial file installed, `PDSF_HARNESS` values unchanged;
- every agent step's recording: present, in format 1, from a real agent, no machine path leaked;
  the recording library (parsing, `rec_apply`);
- **mode A1 played non-interactively on every chapter**, with a `claude` on `PATH` that must never
  be called (zero tokens): every step and every check pass, every agent step is flagged
  `SIMULATED`, and the workspace ends with both local backlogs, `CONTEXT.md` + ADRs on `develop`,
  the Belt US-1 tickets, and the submission rule implemented with `node --test` green. Also: the
  generic layout with chapters 2–3 skipped, and a failing check stopping the mode;
- the recorder, against a fake agent (turns, `--resume`, choices, files, `run`).
