# PDSF Tutorial

Build your first agentic software factory in **about 10 minutes, with zero tokens**, on a small,
realistic Node project: Blackbelt (lite). One command, one path, in your terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/tutorial/tutorial.sh | sh
```

You type the **real** commands: `curl … install.sh | sh` runs the real installer, and the files and
git commits are real. The **agent is simulated**: typing `claude` opens a Claude Code look-alike
inside the tutorial, which replays recordings of real runs of the PDSF skills. Your own `claude` is
never launched, and no token is spent. A **coach** at the bottom of the screen tells you what to do,
in two lines at most.

Needs `sh`, `git` and **Node 18+**, nothing else (no `npm install`). Works on macOS, Linux and
Windows with WSL. Git Bash is best effort: symlinks become copies, and the arrow keys may need
`winpty`.

- **Ctrl-C** quits at any time. Run the same command again to **resume** where you stopped.
- The workspace stays in `~/pdsf-tutorial/blackbelt`: a git repo you can open in your IDE (`code .`
  is one of the steps), explore and delete.
- At the end, press `r` to start over with a fresh workspace.

The tutorial ships with PDSF but is not a skill: `install.sh` never installs any of it into a
project (ADR-0006).

## The journey

| # | Kind | You type | What happens |
|---|---|---|---|
| | read | | Intro card: 3 milestones, ~10 min, 0 token, the agent is SIMULATED |
| 1 | do | `curl -fsSL …/install.sh \| sh` | The real installer runs in the workspace (`.agents/skills` + `.claude` symlinks, no question) and the install is committed |
| 2 | do | `code .` (`s` skips it) | Your IDE opens on the workspace: keep the file tree and the git graph in view |
| 3 | do | `claude` | The screen switches to the simulated harness |
| 4 | do | `/help` | The PDSF skills, `/build-factory` first |
| 5 | do | `/build-factory` | Scaffold pass: 2 questions (↑ ↓ Enter, the recorded answer preselected), the ports written and committed, shown as a diffstat |
| 6 | read | | *Why twice?* One session per pass: a short context means a focused agent, so fewer hallucinations |
| 7 | do | `/clear` | A fresh session. Files and commits stay |
| 8 | do | `/build-factory` | Context pass: `CONTEXT.md` (glossary) and 3 founding ADRs |
| 9 | do | `/verify-factory` | Everything green 🎉 |
| | read | | **Bonus card**: "your first feature", ~3 min. Enter plays it, `s` skips to the end card |
| B1 | read | | The business story Belt US-1 and its rules, read from the workspace's business backlog |
| B2 | do | `/grill-with-docs BELT-US-1` | The agent grills you: **2 questions** (↑ ↓ Enter), then the glossary in `CONTEXT.md` is sharpened and committed on a new `integration/BELT-US-1-…` branch |
| B3 | do | `/to-spec` | The spec in the local technical backlog (`.scratch/belt-submission/SPEC.md`), committed. No question: answer 2 told the agent to go with its recommendations |
| B4 | do | `/to-tickets` | One `ready-for-agent` ticket; the business story links back to it |
| B5 | do | `/implement` | Tests first, then the code, an independent review and the Feature Path; the feature branch is merged into the integration branch |
| B6 | do | `/exit`, then `node --test` | The tests run **for real** in the workspace: 40/40, the 10 new Belt US-1 tests included |
| | read | | End card: what to type tomorrow on your project, and links |

Every step is either **do** (type the command shown as ghost text: **Tab** fills it in) or **read**
(press Enter). In the shell, `ls`, `cat` and `git log` really run. Anything off-script gets a
one-line hint in yellow, never a dead end. `?` gives a hint, and a second `?` lets the tutorial do
the step for you. While the agent works, any key fast-forwards to its next question.

The bonus takes 2 answers in total (the scenario allows at most 3, `maxAnswers`). Its four agent
steps replay one real session (`session: continued`): each skill was typed alone, as you do.

## Entry script (`tutorial.sh`)

```sh
# a branch under review (recette), exactly as a learner would run it:
curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/<branch>/tutorial/tutorial.sh | PDSF_REF=<branch> sh
# offline, from a local checkout (run it from outside the checkout):
PDSF_SRC=/path/to/pdsf sh /path/to/pdsf/tutorial/tutorial.sh
```

1. **Resolves a PDSF source**: `PDSF_SRC`, else `git clone --depth 1 --branch $PDSF_REF` into a temp
   dir, else the tarball of that branch (removed at exit). It never writes into that source.
2. **Prepares the workspace**: `~/pdsf-tutorial/blackbelt` by default. A tutorial workspace that is
   already there is **resumed**. Any other non-empty directory is refused, and so is any directory
   inside the PDSF source. A fresh one gets the fixture, then `git init`, an initial commit on
   `main`, and a `develop` branch checked out (PDSF's git flow starts from `develop`). The marker
   `.git/pdsf-tutorial` makes it a tutorial workspace.
3. **Runs the tutorial app** (`node app/tuto.mjs`) on the terminal (`/dev/tty`, so `curl … | sh`
   stays interactive). When the learner asks to start over (`r`, exit status 75), it removes the
   workspace, creates it again and runs the app again.

| Variable | Meaning | Default |
| --- | --- | --- |
| `PDSF_REF` | Branch of PDSF to fetch. Ignored with `PDSF_SRC`. | `main` |
| `PDSF_SRC` | Local PDSF checkout to play the tutorial from (offline). | fetched |
| `PDSF_TUTO_DIR` | Workspace directory: absent, empty, or a tutorial workspace to resume; outside the source. | `~/pdsf-tutorial/blackbelt` |
| `PDSF_TUTO_SCRIPT` | Play without a keyboard: `auto` (the recorded path) or a file (§ Scripted input). | the keyboard |
| `PDSF_REPO`, `PDSF_TARBALL` | Override the clone and tarball URLs. | GitHub |
| `PDSF_TUTO_SETUP_ONLY` | `y`: stop after preparing the workspace (maintainers, the recorder). | |

The app also reads `PDSF_TUTO_FAST=1` (no streaming animation), `PDSF_TUTO_NO_IDE=1` (never launch
an IDE), and `PDSF_TUTO_FRAMES=<file>` with `PDSF_TUTO_COLS` / `PDSF_TUTO_ROWS` (append every
rendered screen to a file, at that size: the tests check widths and the coach on every screen).

Exit status: `0` done, `130` quit with Ctrl-C (progress saved), `1` an error such as a failing step
check (the workspace is left intact), `3` the scripted input ran out.

## Layout

```
tutorial/
├── tutorial.sh                 ← entry script (curl … | sh)
├── app/
│   ├── tuto.mjs                ← the tutorial app: tutorial shell, simulated harness, coach
│   ├── ui.mjs                  ← terminal UI: display widths, wrap/fit, palette, components
│   ├── keys.mjs                ← keyboard and scripted input
│   ├── readers.mjs             ← reads node --test output (TAP) and a business story
│   └── scenario.mjs            ← scenario loader and linter (`node app/scenario.mjs lint`)
├── scenario/
│   ├── scenario.json           ← THE scenario: chapters, do/read steps, coach texts (format below)
│   ├── 01-build-the-factory/   ← one folder per step that touches the workspace:
│   │   ├── 01-install/         ←   action.sh (runs for real) + check.sh
│   │   └── 02-scaffold/ …      ←   check.sh + recording/ (transcript.md + files/)
│   └── 02-use-the-factory/     ← the bonus chapter: 4 recordings + 05-tests/check.sh
├── lib/
│   ├── scenario.sh             ← shell helpers: frontmatter, step ids, run a check or an action
│   ├── recording.sh            ← read a recording, replay it onto the workspace (rec_apply)
│   └── check.sh                ← helpers for step checks (✓ / ✗ lines)
├── maintainers/
│   └── record/                 ← the recorder: re-records the recordings from real runs (tokens)
├── fixture/blackbelt-lite/     ← the tutorial fixture (its tests: node --test)
└── test/                       ← sh tutorial/test/run.sh
```

## The app (`app/tuto.mjs`)

One Node 18 program, zero npm dependency, raw ANSI, full screen (the alternate screen: your
terminal comes back as it was). It has three parts:

- **Tutorial shell**: a prompt `blackbelt (develop) $` where the deterministic commands run for
  real: the step's expected command, and read-only ones (`ls`, `cat`, `head`, `git log/status/diff/show`,
  `node --test`…). Anything else gets a one-line hint.
- **Simulated harness**: a Claude Code look-alike with a `✻ Claude Code SIMULATED` header, an input
  box, `/help`, `/clear`, `/exit`, tool-call lines (`⏺`), choice lists (`❯`) and diffstats. Free
  text or another slash command gets a "(simulated)" reply. Tabs at the top right show which
  screen you are on.
- **Coach**: the band at the bottom. A rule with the progress dots (`●●●◉○○○○○ 4/9`), at most two
  lines of text, one call to action (the only highlighted element). Cyan while you have something
  to do, green ✓ with numbers once a step is done, yellow for off-script input, red if a check fails.

For an agent step, the app streams the step's condensed **play** (about 3 seconds; any key
fast-forwards), stops on each question with the recorded answer preselected (another answer is
accepted and flagged; the replay stays on the recorded path), then **applies the recording** with
`rec_apply` (the recorded files are written and committed for real), shows the writes and the
commit from real git, and runs the step's **check**.

Progress is saved in `.git/pdsf-tutorial.json` (outside the work tree) after every step.

Rendering never draws a line wider than the terminal: every line goes through `fit` (cut with `…`)
or `wrap` (broken at spaces, hanging indent, long words cut). Both count display columns: wide emoji
count 2. The iteration-1 fixes are kept that way.

## Scenario format

`scenario/scenario.json`, **format 2**. The terminal app reads it; any other surface (a web
playground) can read the same file. `node app/scenario.mjs lint` checks it, and the test suite runs
that check.

```jsonc
{
  "format": 2,
  "intro": { "card": {…}, "coach": ["…"], "cta": "Enter ↵ start" },
  "chapters": [
    { "id": "factory", "title": "Build the factory",
      "card": {…},            // optional: a chapter card (Enter plays, `s` skips the chapter)
      "label": "bonus",       // optional: shown before the progress dots
      "maxAnswers": 3,        // optional: the most questions its plays may ask (the linter checks)
      "steps": [ … ] }
  ],
  "end": { "card": {…}, "coach": ["…"], "cta": "q quit  ·  r restart" },
  "texts": { … }              // the app's own words: asking, almost, stuck, resumed…
}
```

A **step**:

| Key | Meaning |
| --- | --- |
| `id` | Unique id (`install`, `scaffold`…). |
| `kind` | `do` (the learner types something) or `read` (the learner reads, then presses Enter). |
| `screen` | `shell` or `harness`: where the step happens. |
| `expect` | *do* only, required: the expected input, shown as ghost text (Tab fills it in). |
| `accept` | Optional regex: other inputs that count (e.g. any `curl … install.sh \| sh`). |
| `name` | Optional: how the coach names the input when `expect` is too long ("the install command"). |
| `skip` | Optional: an input that skips the step (`s` for `code .`), ending on `skipped`. |
| `coach` | 1–2 lines, each ≤ 74 columns: what to do, then optionally why. `{ws}`, `{skills}`, `{files}`, `{adrs}`, `{commits}`, `{ide}` are filled in. |
| `cta` | The call to action ("Type /build-factory", "Enter ↵ got it"). Required on every step. |
| `hint` | *do*: the one line `?` shows. |
| `done` | *do*: 1–2 lines once the step is done (green ✓), with numbers. |
| `dir` | Optional: the step folder under `scenario/` holding its `check.sh` (always run), its `action.sh` (run for real; `@var name=value` output lines feed the coach) and its `recording/`. |
| `effect` | Optional, built into the app: `harness` (enter the harness), `shell` (leave it), `help`, `clear`, `ide`, `test` (run `node --test` for real and show its summary: tests per file, the ones new since `main`, the totals; `{tests}`, `{pass}`, `{fresh}` feed the coach). |
| `help`, `also` | For the `help` effect: the skills to show with a description, then the ones to name. |
| `play` | Optional: the condensed replay of the step's recording (below). |
| `tip` | *read*: a box in the scrollback (the "why twice?" context gauge). |
| `story` | *read*: `{file, label, section}`, a box with a business story's title, one of its sections (the intention) and how many business rules it has, read from the workspace (the file must be in the fixture). |

A **play** is a list of items: `{"tool": "Bash(…)", "note": "…", "style": "green"}` (the note is
optional), `{"say": "text"}` (`# ` for a heading; slash
commands are coloured), `{"ask": "question", "choices": [...], "pick": 0, "turn": 3}`,
`{"writes": [{"path", "note"}], "stat": true, "more": "ADRs"}` (after the recording is applied,
from real git), `{"commit": true}`, `{"checks": [...], "na": "…"}`. A question's `turn` is the
learner turn of the transcript it condenses: the linter checks that this turn is a recorded answer
with alternatives. The tutorial shows a short, faithful excerpt of the real run; the full run is in
the transcript.

A **card** line is a string, or one of `{"dim"}`, `{"ok"}`, `{"cmd"}`, `{"simulated"}`, `{"link": [label,
url]}`, `{"bonus"}` (purple), `{"story": [id, title]}`, `{"flow": [command, …]}` (`a → b → c`) and
`{"keys": [[key, label], …]}`. A chapter card also takes a `title` and a `width`.

The **linter** enforces: valid kinds and screens; every coach text 1–2 lines that fit an
80-column terminal; every *do* step has an expected input (matching its `accept`), a hint and a
`done`; every step has a call to action; every `dir` has a `check.sh`; every played step has a
recording, and every question points at a recorded answer; a chapter's questions stay within its
`maxAnswers`; a `story` is a file of the fixture.

## Scripted input

`PDSF_TUTO_SCRIPT=auto` plays the recorded path: Tab and Enter on every *do* step, the recorded
answer to every question, Enter on the bonus card (it plays the bonus), `q` on the end card.
`PDSF_TUTO_SCRIPT=<file>` reads the keys from a file,
one item per line:

```
# a comment
ls                  ← typed, then Enter
{enter}             ← one key: enter, tab, up, down, left, right, backspace, esc, ctrl-c
{?}                 ← one character key ({s}, {q}, {r}…)
{auto}              ← from here on, the recorded path
```

When the file runs out (without `{auto}`), the app stops with status 3. With a scripted input, the
app writes a plain transcript to stdout (screens, coach changes, `check <step>: … all pass`) instead
of drawing the screen. This is how `tutorial/test/run.sh` plays the whole journey.

## Recordings

Each agent step's folder holds `recording/transcript.md` (a real session, turn by turn) and
`recording/files/` (the files that run produced, as workspace-relative paths). The app applies
`files/` with `rec_apply` and commits, so the workspace ends exactly where the real run left it.

The transcript starts with a frontmatter:

| Key | Meaning |
| --- | --- |
| `step` | The step folder id, `<chapter>/<step>`. |
| `command` | The command the session starts with (the step's `expect`). |
| `branch` | The branch the run ended on. The replay switches to it, creating it from `HEAD` if absent. |
| `commit` | The message of the replayed commit: the last commit the agent made (else the recorder's). |
| `session` | `new`, or `continued`: the step ran in the **previous step's agent session**. |
| `via` | Optional. A branch the run created, committed on, then merged into `branch` (e.g. `/implement`'s `feature/*`). The replay commits there and merges it back `--no-ff`. |
| `merge` | The message of that merge commit. |
| `branches` | Other branches the run created (space-separated); the replay creates them at the end. |
| `removed` | Paths the run deleted (space-separated). |
| `recorded`, `recorder`, `pdsf`, `harness` | When, with which agent (`Claude Code <version>, <model>`), from which PDSF commit, on which harness layout. |
| `format` | `1`. |

Then a short header, then the **turns**, in order, each starting with a marker line:

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

- Turns alternate, the **learner first** (the command as typed) and the **agent last**.
- A **learner turn** is the recorded answer. Its optional `pdsf-choices` line holds the
  **alternative** answers (`|`-separated): the scenario's questions offer them.
- An **agent turn** is what the learner would see in their harness: the agent's text and one
  `⏺ Tool(target)` line per tool call. Subagent traffic is left out. Paths are relative to the
  workspace.

`rec_apply STEP` (in `lib/recording.sh`) switches to `branch` (and `via`), copies `files/` over the
workspace, deletes `removed`, commits with `commit`, merges `via` back and creates `branches`. The
step's check then judges the result.

### Re-recording (maintainers)

**A skill changed? Re-record** the recordings with `tutorial/maintainers/record/record.sh`, then
run `sh tutorial/test/run.sh`.

The test suite replays every recording and runs every step check: it is the drift guard. The
recorder spends tokens. It drives a real, non-interactive Claude Code session in a tutorial
workspace: one `claude -p` call per learner turn, `--resume` in between, `--permission-mode
bypassPermissions` (the workspace is a throwaway). It needs `claude`, logged in, and `node`.

```sh
R=tutorial/maintainers/record/record.sh
sh $R steps                               # the recorded steps, in order

# Re-record everything with the recorded answers (each step continues from the previous one):
sh $R all /tmp/rec-ws

# Re-record one step, adapting the answers to what the agent now asks:
sh $R prepare 01-build-the-factory/03-context /tmp/rec-ws   # setup + install for real, earlier steps replayed
sh $R turn /tmp/rec-ws /build-factory
sh $R turn /tmp/rec-ws --choices "1 keep belt for both, the rest as recommended" "1 ok, 2 ok, …"
# … one `turn` per answer, reading each question first …
sh $R finish 01-build-the-factory/03-context /tmp/rec-ws    # writes the recording, runs the check
# A next step that ran in the same agent session (session: continued):
sh $R turn /tmp/rec-ws --continue /to-spec
```

- `run STEP WS` replays the learner turns of the current transcript against the real agent, then
  `finish`es. Use it when the questions did not change.
- `finish` commits what the agent left uncommitted, copies every path changed since the step
  started into `files/`, writes `transcript.md` and **runs the step's check**: a recording that
  fails its check is rejected.
- Then review the step's `play` in `scenario.json`: it is a condensed excerpt of the transcript.
  Make it say what the new run says, and keep each question's `turn` pointing at its recorded
  answer (the linter checks it).
- A step depends on the previous ones: after re-recording step N, re-record (or at least re-test)
  the steps after it.
- The recorded agent runs without auto-memory (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`): it must not
  write outside the throwaway workspace, nor remember an earlier recording.
- A learner answer that pre-approves the next skills ("go with your recommendations") must also say
  to stop there, or the agent chains `/to-spec` and `/to-tickets` in the same turn. The bonus was
  recorded that way, so its later skills ask nothing.
- `PDSF_RECORD_MODEL` passes `--model`; `PDSF_RECORD_CLAUDE` replaces the agent command (the test
  suite uses a fake one).

## Tests

```sh
sh tutorial/test/run.sh                    # everything below, about a minute, no token
node --test tutorial/test/app.test.mjs     # the app's unit tests only
```

- **The seam**: `tutorial.sh` played end to end with `PDSF_TUTO_SCRIPT` (the recorded path, and an
  off-script session with Ctrl-C then a resume), asserting the transcript, every step check, the
  workspace and its git history (the bonus included: its integration branch, the merged feature,
  a real `node --test` at 40/40; and skipping it with `s`), and **every rendered screen** at 60×20,
  80×24 and 120×40: no line wider than the terminal, the coach band always the last 4 rows (so at
  most 2 lines of text), a progress indicator and a call to action on every screen. A `claude` on `PATH` must never run.
- **Unit** (`node --test`): widths, wrap and fit, components, key parsing, scripted input, the TAP
  and story readers, the scenario (the bonus chapter included) and its linter (on broken copies).
- **Recordings**: their format, the recording library, the recorder (with a fake agent).
- **Contract**: `install.sh` installs no tutorial file; `PDSF_HARNESS` keeps its values.
- **Fixture**: `cd tutorial/fixture/blackbelt-lite && node --test`.
