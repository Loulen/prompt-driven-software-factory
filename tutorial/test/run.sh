#!/bin/sh
# PDSF Tutorial — test suite. The seam is the entry script, played non-interactively with a scripted
# input (PDSF_TUTO_SCRIPT) from this checkout (PDSF_SRC) in temp dirs: it asserts what the learner
# sees (the transcript, every rendered screen) and the workspace state after each step. Plus the
# app's unit tests (node --test), the recording library, the recorder and the install.sh contract.
#
#   sh tutorial/test/run.sh
#
# Needs sh, git, node 18+. Never writes into the checkout, never calls a model.
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
TUTO="$REPO/tutorial/tutorial.sh"
SCEN="$REPO/tutorial/scenario"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/home"

PASS=0; FAIL=0; CURRENT=""

t() { CURRENT=$1; printf '%s\n' "• $1"; }
ok() { PASS=$((PASS + 1)); }
ko() { FAIL=$((FAIL + 1)); printf '  FAIL [%s] %s\n' "$CURRENT" "$1"; }
assert() { _what=$1; shift; if "$@" >/dev/null 2>&1; then ok; else ko "$_what"; fi; }
assert_not() { _what=$1; shift; if "$@" >/dev/null 2>&1; then ko "$_what"; else ok; fi; }
assert_out() { if grep -qF -- "$2" "$1"; then ok; else ko "output lacks: $2"; fi; }
assert_no_out() { if grep -qF -- "$2" "$1"; then ko "output has: $2"; else ok; fi; }

# A `claude` on PATH that must never run: typing `claude` in the tutorial is the simulated harness.
cat >"$TMP/bin/claude" <<EOF
#!/bin/sh
printf 'REAL CLAUDE CALLED %s\n' "\$*" >> "$TMP/real-claude.calls"
EOF
chmod +x "$TMP/bin/claude"
BASE_PATH="$TMP/bin:$PATH"

# tuto DIR LOG [VAR=value…] — play the tutorial from this checkout, no terminal, the recorded path
# unless PDSF_TUTO_SCRIPT says otherwise, no IDE launched, screens dumped to LOG.frames.
tuto() {
  _dir=$1; _log=$2; shift 2
  rm -f "$_log.frames"
  ( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$REPO" PDSF_TUTO_DIR="$_dir" \
      PDSF_TUTO_SCRIPT=auto PDSF_TUTO_NO_IDE=1 PDSF_TUTO_FRAMES="$_log.frames" "$@" sh "$TUTO" ) </dev/null >"$_log" 2>&1
}

# A copy of the PDSF source, to break it on purpose.
fake_src() {
  _fs="$TMP/src-$1"
  mkdir -p "$_fs"
  ( cd "$REPO" && tar cf - --exclude=.git --exclude=.pdo . ) | ( cd "$_fs" && tar xf - )
  printf '%s' "$_fs"
}

# frames_ok FRAMES COLS ROWS -> checks every rendered screen; prints the first problem.
frames_ok() { node "$REPO/tutorial/test/check-frames.mjs" "$@" 2>&1; }

# ---------------------------------------------------------------------------- unit

t "the app's unit tests pass (widths, wrapping, keys, scenario linter)"
node --test "$REPO/tutorial/test/app.test.mjs" >"$TMP/unit.log" 2>&1
assert "node --test tutorial/test/app.test.mjs" test $? -eq 0
[ "$FAIL" -eq 0 ] || grep -E '^not ok|# fail' "$TMP/unit.log"

t "the scenario linter passes"
node "$REPO/tutorial/app/scenario.mjs" lint >"$TMP/lint.log" 2>&1
assert "scenario.mjs lint exits 0" test $? -eq 0

# ---------------------------------------------------------------------------- the journey

t "the whole journey, scripted (the recorded path): every step and every check pass, zero tokens"
tuto ws "$TMP/journey.log"
RC=$?
WS="$TMP/ws"
assert "tutorial exits 0" test "$RC" -eq 0
[ "$RC" -eq 0 ] || tail -20 "$TMP/journey.log"
assert_out "$TMP/journey.log" "You type the real commands. The agent is  SIMULATED ."
assert_out "$TMP/journey.log" "1 install PDSF    2 /build-factory ×2    3 /verify-factory"
for _s in install ide claude help scaffold why-twice clear context verify; do
  assert_out "$TMP/journey.log" "factory/$_s ("
done
for _s in install scaffold context verify; do
  assert "the $_s check passes" grep -q "check $_s: .* all pass" "$TMP/journey.log"
done
assert_out "$TMP/journey.log" "PDSF installer · "
assert_out "$TMP/journey.log" "✓ 16 skills → .agents/skills"
assert_out "$TMP/journey.log" "[screen: claude · simulated]"
assert_out "$TMP/journey.log" "PDSF skills (16 · .claude/skills)"
assert_out "$TMP/journey.log" "/build-factory    wire the backlogs"
assert_out "$TMP/journey.log" "The agent is asking you a question (1/2)."
assert_out "$TMP/journey.log" "❯ 1. business-backlog/ — markdown files (found in the repo)"
assert_out "$TMP/journey.log" "The agent is asking you a question (2/2)."
assert_out "$TMP/journey.log" "+ docs/agents/business-backlog.md  +52"
assert_out "$TMP/journey.log" "why twice?"
assert_out "$TMP/journey.log" "Less context, fewer hallucinations. /clear, then /build-factory again."
assert_out "$TMP/journey.log" "Context cleared. The agent forgot this session; files and commits stay."
assert_out "$TMP/journey.log" "The agent is asking you a question (1/1)."
assert_out "$TMP/journey.log" "Context written: a glossary and 3 ADRs."
assert_out "$TMP/journey.log" "✓ Scaffold present"
assert_out "$TMP/journey.log" "🎉 Your factory is built. 8 checks green, 3 commits."
assert_out "$TMP/journey.log" "Tomorrow, on your project"
assert_out "$TMP/journey.log" "[ q quit  ·  r restart ]"
assert_out "$TMP/journey.log" "curl -fsSL https://raw.githubusercontent.com/Loulen/prompt-driven-software-factory/main/install.sh | sh"
assert "the workspace is a git repo, on the story's integration branch (the bonus)" test "$(git -C "$WS" symbolic-ref --short HEAD)" = integration/BELT-US-1-submit-belt-for-validation
assert "main holds the fixture's initial commit only" test "$(git -C "$WS" log --format=%s main)" = "Blackbelt (lite): initial commit"
assert "develop: install, scaffold, context — committed for real" test "$(git -C "$WS" log --format=%s main..develop | tr '\n' '~')" = "Bootstrap project context: glossary + foundational ADRs~Wire the agentic factory: ports, method constants, scaffold~Install PDSF 0.7.0~"
assert "the skills and AGENTS.md are in the workspace" sh -c "[ -f '$WS/.agents/skills/build-factory/SKILL.md' ] && grep -q 'PDSF:BEGIN' '$WS/AGENTS.md'"
assert "the .claude overlay: symlinks only" sh -c "[ \"\$(readlink '$WS/.claude/skills')\" = ../.agents/skills ] && [ \"\$(readlink '$WS/CLAUDE.md')\" = AGENTS.md ]"
assert "the ports are in docs/agents/" test -f "$WS/docs/agents/issue-tracker.md"
assert "CONTEXT.md and 3 ADRs" sh -c "grep -q Belt '$WS/CONTEXT.md' && [ \"\$(ls '$WS'/docs/adr/*.md | wc -l | tr -d ' ')\" -eq 3 ]"
assert "the working tree is clean" sh -c "[ -z \"\$(git -C '$WS' status --porcelain)\" ]"
assert "the fixture's tests still pass in the workspace" sh -c "cd '$WS' && node --test </dev/null"
assert "typing claude never launched the real claude" test ! -e "$TMP/real-claude.calls"
assert "the progress is saved as done" grep -q '"step": 15' "$WS/.git/pdsf-tutorial.json"
assert "the tutorial's own files stay out of the workspace tree" sh -c "! git -C '$WS' ls-files | grep -qi tutorial"

t "the bonus: Belt US-1 from /grill-with-docs to /implement, 2 answers, then node --test for real"
for _s in story grill spec tickets implement tests; do
  assert_out "$TMP/journey.log" "bonus/$_s ("
done
for _s in grill spec tickets implement tests; do
  assert "the bonus $_s check passes" grep -q "check $_s: .* all pass" "$TMP/journey.log"
done
assert_out "$TMP/journey.log" "Bonus · 3 min: take a user story all the way to green tests."
assert_out "$TMP/journey.log" "/grill-with-docs → /to-spec → /to-tickets → /implement → node --test"
assert_out "$TMP/journey.log" "Belt US-1 [user] Submit my belt for sensei validation"
assert_out "$TMP/journey.log" "Belt US-1: a consultant submits their belt once its objectives are done."
assert_out "$TMP/journey.log" "> /grill-with-docs BELT-US-1"
assert "the bonus asks 2 answers in total (at most 3)" test "$(sed -n '/### step 10\//,$p' "$TMP/journey.log" | grep -c '^  answered: ')" -eq 2
assert_out "$TMP/journey.log" "> /to-spec"
assert_out "$TMP/journey.log" "> /to-tickets"
assert_out "$TMP/journey.log" "> /implement"
assert_out "$TMP/journey.log" "+ .scratch/belt-submission/SPEC.md"
assert_out "$TMP/journey.log" "⏺ merge "
assert_out "$TMP/journey.log" "$ node --test"
assert_out "$TMP/journey.log" "ℹ tests 40  pass 40  fail 0"
assert_out "$TMP/journey.log" "40/40 green, 10 new. A user story went from the backlog to code."
_ib=integration/BELT-US-1-submit-belt-for-validation
assert "develop keeps the factory only" test "$(git -C "$WS" rev-list --count main..develop)" -eq 3
assert "the integration branch: grilling, spec, tickets, then the feature merged --no-ff" test "$(git -C "$WS" log --first-parent --format=%s develop.."$_ib" | tr '\n' '~')" = "Merge feature/01-submit-belt into $_ib~BELT-US-1 tickets: 01 submit a belt~BELT-US-1 spec: submit a belt for a sensei's decision~BELT-US-1 grilling: belt's consultant, submission to any sensei~"
assert "the feature branch holds the code commit" test "$(git -C "$WS" log -1 --format=%s feature/01-submit-belt)" = "01 submit a belt for a sensei's decision (BELT-US-1)"
assert "the spec and the ticket are on the local technical backlog, the ticket done" sh -c "[ -f '$WS/.scratch/belt-submission/SPEC.md' ] && grep -q '^\*\*Status:\*\* done' '$WS/.scratch/belt-submission/tickets/01-submit-belt.md'"
assert "the business story links back to its ticket" grep -q '^## Comments' "$WS/business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md"
assert "Belt US-1 is implemented: submit refuses while objectives remain, listing them" sh -c "cd '$WS' && node src/cli.js submit B-2 ada 2>&1 | grep -q 'still to validate: 2. Run a refactoring workshop'"
assert "node --test passes in the workspace, with the new Belt US-1 tests" sh -c "cd '$WS' && node --test </dev/null >'$TMP/ws-tests.log' 2>&1 && grep -q '^# pass 40' '$TMP/ws-tests.log' && grep -q '^ok .* - a belt with objectives still to validate is refused, listing them' '$TMP/ws-tests.log'"

t "skipping the bonus (s on its card) goes straight to the end card"
{
  printf '{enter}\n'                                                   # intro
  for _k in install ide claude help; do printf '{tab}\n{enter}\n{enter}\n'; done
  printf '{tab}\n{enter}\n{enter}\n{enter}\n{enter}\n'                   # scaffold: 2 questions
  printf '{enter}\n'                                                   # why twice
  printf '{tab}\n{enter}\n{enter}\n'                                   # clear
  printf '{tab}\n{enter}\n{enter}\n{enter}\n'                           # context: 1 question
  printf '{tab}\n{enter}\n{enter}\n'                                   # verify
  printf '{s}\n{q}\n'                                                  # bonus card: skip; end card: quit
} >"$TMP/skip.txt"
tuto ws-skip "$TMP/skip.log" PDSF_TUTO_SCRIPT="$TMP/skip.txt"
assert "the tutorial ends with status 0" test $? -eq 0
assert_out "$TMP/skip.log" "Enter ↵ play the bonus  ·  s skip to the end"
assert_no_out "$TMP/skip.log" "bonus/story ("
assert_out "$TMP/skip.log" "Tomorrow, on your project"
assert "no bonus work in the workspace: still on develop" test "$(git -C "$TMP/ws-skip" symbolic-ref --short HEAD)" = develop
assert "the progress is saved as done" grep -q '"step": 15' "$TMP/ws-skip/.git/pdsf-tutorial.json"

t "in the bonus, node --test typed in the harness asks to /exit first; the bonus can be resumed"
{
  sed '$d' "$TMP/skip.txt" | sed '$d'                                   # the factory, up to the bonus card
  printf '{enter}\n{enter}\n'                                           # bonus card: play; the story
  printf '{tab}\n{enter}\n{down}\n{enter}\n{enter}\n{enter}\n'             # grill: an off-path 1st answer
  printf '{ctrl-c}\n'
} >"$TMP/bonus1.txt"
tuto ws-bonus "$TMP/bonus1.log" PDSF_TUTO_SCRIPT="$TMP/bonus1.txt"
assert "Ctrl-C in the bonus quits with status 130" test $? -eq 130
assert_out "$TMP/bonus1.log" "answered: 2. All ok, but submit names one sensei (Q3)"
assert_out "$TMP/bonus1.log" "progress saved at step 3/6 (Bonus · first feature)"
{
  for _k in spec tickets implement; do printf '{tab}\n{enter}\n{enter}\n'; done
  printf 'node --test\n{auto}\n'
} >"$TMP/bonus2.txt"
tuto ws-bonus "$TMP/bonus2.log" PDSF_TUTO_SCRIPT="$TMP/bonus2.txt"
assert "the resumed bonus ends with status 0" test $? -eq 0
assert_out "$TMP/bonus2.log" "↻ Resumed at step 3/6: your workspace kept its files and commits."
assert_out "$TMP/bonus2.log" "This one runs in the shell: type /exit first."
assert_out "$TMP/bonus2.log" "ℹ tests 40  pass 40  fail 0"
assert "the resumed bonus is done: the feature is merged" sh -c "git -C '$TMP/ws-bonus' log --format=%s | grep -q 'Merge feature/01-submit-belt'"

t "every screen fits the terminal, the coach never shows more than 2 lines, progress on every step"
FR=$(frames_ok "$TMP/journey.log.frames" 80 24)
assert "80×24: $FR" test -z "$FR"
tuto ws-narrow "$TMP/narrow.log" PDSF_TUTO_COLS=60 PDSF_TUTO_ROWS=20
FR=$(frames_ok "$TMP/narrow.log.frames" 60 20)
assert "60×20: $FR" test -z "$FR"
tuto ws-wide "$TMP/wide.log" PDSF_TUTO_COLS=120 PDSF_TUTO_ROWS=40
FR=$(frames_ok "$TMP/wide.log.frames" 120 40)
assert "120×40: $FR" test -z "$FR"
assert "the harness screens are labelled SIMULATED" grep -q '✻ Claude Code   SIMULATED' "$TMP/journey.log.frames"
assert "the shell and harness tabs are shown" grep -q 'shell   claude · simulated' "$TMP/journey.log.frames"
assert "the intro and end cards are shown" sh -c "grep -q 'P D S F  ·  build your software factory' '$TMP/journey.log.frames' && grep -q 'Tomorrow, on your project' '$TMP/journey.log.frames'"
assert "progress 1/9 … 9/9 then done" sh -c "grep -q '◉○○○○○○○○ 1/9' '$TMP/journey.log.frames' && grep -q '●●●●●●●●◉ 9/9' '$TMP/journey.log.frames' && grep -q '●●●●●●●●● done' '$TMP/journey.log.frames'"
assert "the bonus screens were checked too: bonus 1/6 … 6/6" sh -c "grep -q 'bonus ◉○○○○○ 1/6' '$TMP/journey.log.frames' && grep -q 'bonus ●●●●●◉ 6/6' '$TMP/journey.log.frames'"
assert "the bonus card is drawn" grep -q 'bonus · ~3 min' "$TMP/journey.log.frames"

t "off-script input gets a one-line hint, never a dead end; ? hints, ?? does the step; Ctrl-C saves"
cat >"$TMP/offscript.txt" <<'EOF'
# intro card
{enter}
# install step: real read-only commands, an unknown one, then ? and ?? (do it for me)
ls
cat package.json
git log --oneline
rm -rf src
claude
{?}
{?}
{enter}
{enter}
# ide: skipped
s
{enter}
# claude
/help
claude
{enter}
# /help off-script talk, then /help
hello agent
/help
{enter}
# scaffold: the second answer to the first question (off the recorded path)
/verify-factory
/build-factory
{down}
{enter}
{enter}
{enter}
# why twice
{enter}
# clear: leave the harness, come back, then quit
/exit
git status
claude
{ctrl-c}
EOF
tuto ws-off "$TMP/off.log" PDSF_TUTO_SCRIPT="$TMP/offscript.txt"
assert "Ctrl-C quits with status 130" test $? -eq 130
assert_out "$TMP/off.log" "package.json"
assert_out "$TMP/off.log" '"name": "blackbelt-lite"'
assert_out "$TMP/off.log" "Blackbelt (lite): initial commit"
assert_out "$TMP/off.log" "tutorial shell: rm: not available here (try ls, cat, git log)"
assert_out "$TMP/off.log" "Almost: the install command is the one we need here."
assert_out "$TMP/off.log" "Press Tab: it types the install command for you. Then Enter."
assert_out "$TMP/off.log" "Stuck? The tutorial can do this step for you."
assert_out "$TMP/off.log" "No IDE for now: open"
assert_out "$TMP/off.log" "This one runs in the harness: type claude first."
assert_out "$TMP/off.log" "(simulated) This stand-in only replays recorded sessions: no model is called."
assert_out "$TMP/off.log" "(simulated) /verify-factory is not recorded here. On your project, it runs for real."
assert_out "$TMP/off.log" "Almost: /build-factory is the one we need here."
assert_out "$TMP/off.log" "answered: 2. Jira"
assert_out "$TMP/off.log" "↳ Not the recorded answer: noted. The replay goes on with answer 1."
assert_out "$TMP/off.log" "You left the simulated harness. Type claude to go back."
assert_out "$TMP/off.log" "progress saved at step 7/9 (Build the factory). Re-run the same command to resume."
assert "the src/ folder survived rm -rf src" test -f "$TMP/ws-off/src/blackbelt.js"
assert "the recorded path went on: the scaffold is there" grep -q 'business-backlog/' "$TMP/ws-off/docs/agents/business-backlog.md"
assert "quitting leaves the workspace intact and committed" sh -c "[ -z \"\$(git -C '$TMP/ws-off' status --porcelain)\" ] && git -C '$TMP/ws-off' log --format=%s | grep -q 'Wire the agentic factory'"
assert "the progress is saved at step 7" grep -q '"step": 6' "$TMP/ws-off/.git/pdsf-tutorial.json"
assert "typing claude never launched the real claude" test ! -e "$TMP/real-claude.calls"

t "re-running the same command resumes where the learner stopped"
tuto ws-off "$TMP/resume.log"
assert "the resumed run ends with status 0" test $? -eq 0
assert_out "$TMP/resume.log" "resuming in $TMP/ws-off"
assert_out "$TMP/resume.log" "↻ Resumed at step 7/9: your workspace kept its files and commits."
assert_no_out "$TMP/resume.log" "P D S F  ·  build your software factory"
assert_no_out "$TMP/resume.log" "factory/scaffold ("
assert "the resumed run finishes the factory" sh -c "git -C '$TMP/ws-off' log --format=%s | grep -q 'Bootstrap project context'"
assert "the install is not replayed: one install commit" test "$(git -C "$TMP/ws-off" log --format=%s | grep -c 'Install PDSF')" -eq 1

t "the end card's r restarts with a fresh workspace"
printf '{r}\n' >"$TMP/restart.txt"
tuto ws-off "$TMP/restart.log" PDSF_TUTO_SCRIPT="$TMP/restart.txt"
assert "the restarted app waits on its intro card (the script ran out: status 3)" test $? -eq 3
assert_out "$TMP/restart.log" "starting over with a fresh workspace"
assert "the workspace is fresh again" test "$(git -C "$TMP/ws-off" log --format=%s | tr '\n' '~')" = "Blackbelt (lite): initial commit~"

t "a failing step check stops the tutorial, workspace intact"
SRC=$(fake_src badcheck)
printf 'echo "  ✗ the scaffold is missing"\nexit 1\n' >"$SRC/tutorial/scenario/01-build-the-factory/02-scaffold/check.sh"
( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$SRC" PDSF_TUTO_DIR="$TMP/ws-bad" PDSF_TUTO_SCRIPT=auto PDSF_TUTO_NO_IDE=1 sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/bad.log" 2>&1
assert "exits non-zero" test $? -eq 1
assert_out "$TMP/bad.log" "✗ the scaffold is missing"
assert_out "$TMP/bad.log" "This step's check failed (✗ lines above). Your workspace is intact."
assert_out "$TMP/bad.log" "error: the check of scaffold failed"
assert_no_out "$TMP/bad.log" "factory/why-twice"
assert "the workspace keeps its commits" sh -c "git -C '$TMP/ws-bad' log --format=%s | grep -q 'Wire the agentic factory'"

# ---------------------------------------------------------------------------- entry script

t "the entry script works piped into sh (curl … | sh)"
( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$REPO" PDSF_TUTO_DIR="$TMP/ws-pipe" PDSF_TUTO_SCRIPT=auto PDSF_TUTO_NO_IDE=1 sh <"$TUTO" ) >"$TMP/pipe.log" 2>&1
assert "piped tutorial exits 0" test $? -eq 0
assert "piped tutorial builds the factory" grep -q Belt "$TMP/ws-pipe/CONTEXT.md"

t "the default workspace is ~/pdsf-tutorial/blackbelt"
( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$REPO" PDSF_TUTO_SETUP_ONLY=y sh "$TUTO" ) </dev/null >"$TMP/default.log" 2>&1
assert "setup-only exits 0" test $? -eq 0
assert "~/pdsf-tutorial/blackbelt is a fresh workspace on develop" sh -c "[ \"\$(git -C '$TMP/home/pdsf-tutorial/blackbelt' symbolic-ref --short HEAD)\" = develop ] && [ -f '$TMP/home/pdsf-tutorial/blackbelt/.git/pdsf-tutorial' ]"
assert "setup-only does not install PDSF" test ! -e "$TMP/home/pdsf-tutorial/blackbelt/.agents"

t "a non-empty directory that is not a tutorial workspace is refused, and left untouched"
mkdir -p "$TMP/busy" && printf 'keep\n' >"$TMP/busy/mine.txt"
tuto busy "$TMP/busy.log"
assert "refused" test $? -ne 0
assert_out "$TMP/busy.log" "is not empty and is not a tutorial workspace"
assert "left untouched" sh -c "[ \"\$(ls -A '$TMP/busy')\" = mine.txt ]"

t "an empty existing directory is accepted"
mkdir -p "$TMP/empty"
tuto empty "$TMP/empty.log" PDSF_TUTO_SETUP_ONLY=y
assert "accepted" test $? -eq 0
assert "fixture copied" test -f "$TMP/empty/src/blackbelt.js"

t "the tutorial never writes into the PDSF source"
SRC=$(fake_src inside)
_before=$(cd "$SRC" && find . | LC_ALL=C sort | cksum)
( cd "$TMP" && env HOME="$TMP/home" PDSF_SRC="$SRC" PDSF_TUTO_DIR="$SRC/ws" PDSF_TUTO_SCRIPT=auto sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/inside.log" 2>&1
assert "a workspace inside the source is refused" test $? -ne 0
assert_out "$TMP/inside.log" "the tutorial never writes there"
( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$SRC" PDSF_TUTO_DIR="$TMP/ws-src" PDSF_TUTO_SCRIPT=auto PDSF_TUTO_NO_IDE=1 sh "$SRC/tutorial/tutorial.sh" ) </dev/null >/dev/null 2>&1
assert "a full run leaves the source unchanged" test "$(cd "$SRC" && find . | LC_ALL=C sort | cksum)" = "$_before"

t "no terminal and no scripted input: a clear error"
if command -v setsid >/dev/null 2>&1; then
  ( cd "$TMP" && env HOME="$TMP/home" PATH="$BASE_PATH" PDSF_SRC="$REPO" PDSF_TUTO_DIR="$TMP/ws-notty" setsid sh "$TUTO" ) </dev/null >"$TMP/notty.log" 2>&1
  assert "refused" test $? -ne 0
  assert_out "$TMP/notty.log" "the tutorial needs a terminal"
fi
PDSF_TUTO_WORKSPACE="$TMP/ws" node "$REPO/tutorial/app/tuto.mjs" </dev/null >"$TMP/notty-app.log" 2>&1
assert "the app alone refuses too" test $? -ne 0
assert_out "$TMP/notty-app.log" "no terminal"

t "PDSF_REF fetches that branch (git clone), and a missing ref fails clearly"
REMOTE="$TMP/remote"
mkdir -p "$REMOTE"
( cd "$REPO" && tar cf - --exclude=.git --exclude=.pdo . ) | ( cd "$REMOTE" && tar xf - )
git -C "$REMOTE" init -q && git -C "$REMOTE" checkout -q -b recette/tuto-21 \
  && git -C "$REMOTE" add -A && git -C "$REMOTE" -c user.name=t -c user.email=t@t commit -q -m snapshot
( cd "$TMP" && env -u PDSF_SRC HOME="$TMP/home" PATH="$BASE_PATH" PDSF_REPO="$REMOTE" PDSF_REF=recette/tuto-21 PDSF_TUTO_DIR="$TMP/ws-ref" PDSF_TUTO_SETUP_ONLY=y sh "$TUTO" ) </dev/null >"$TMP/ref.log" 2>&1
assert "PDSF_REF=<branch> works" test $? -eq 0
assert_out "$TMP/ref.log" "fetching PDSF (recette/tuto-21)"
assert "the workspace comes from the fetched branch" test -f "$TMP/ws-ref/src/blackbelt.js"
( cd "$TMP" && env -u PDSF_SRC HOME="$TMP/home" PATH="$BASE_PATH" PDSF_REPO="$REMOTE" PDSF_TARBALL="file://$TMP/nope.tgz" PDSF_REF=no-such-branch PDSF_TUTO_DIR="$TMP/ws-noref" PDSF_TUTO_SETUP_ONLY=y sh "$TUTO" ) </dev/null >"$TMP/noref.log" 2>&1
assert "an unknown ref is refused" test $? -ne 0
assert_out "$TMP/noref.log" "could not fetch PDSF (no-such-branch)"
assert "and no workspace is created" test ! -e "$TMP/ws-noref"

t "--help documents the entry contract"
sh "$TUTO" --help >"$TMP/help.log" 2>&1
assert "--help exits 0" test $? -eq 0
for _v in PDSF_REF PDSF_SRC PDSF_TUTO_DIR PDSF_TUTO_SCRIPT "~/pdsf-tutorial/blackbelt"; do
  assert_out "$TMP/help.log" "$_v"
done

# ---------------------------------------------------------------------------- iteration 1 is gone

t "one path: the modes, the mode menu and the guide skill are gone; the recorder is the maintainers'"
assert "no tutorial/modes/" test ! -e "$REPO/tutorial/modes"
assert "no pdsf-tutorial guide skill anywhere" sh -c "[ -z \"\$(find '$REPO' -path '$REPO/.git' -prune -o -path '$REPO/.pdo' -prune -o -name 'pdsf-tutorial' -print)\" ]"
assert "no mode menu nor harness question in the entry script" sh -c "! grep -qE 'PDSF_TUTO_MODE|PDSF_TUTO_HARNESS|choose_harness' '$TUTO'"
assert "no step.md / chapter.md left (the scenario is scenario.json)" sh -c "[ -z \"\$(find '$SCEN' -name step.md -o -name chapter.md)\" ]"
assert "the recorder lives in tutorial/maintainers/record/" test -f "$REPO/tutorial/maintainers/record/record.sh"
assert "the tutorial README says how to re-record" grep -qF 'A skill changed? Re-record' "$REPO/tutorial/README.md"

# ---------------------------------------------------------------------------- checks + recordings

PDSF_TUTO_ROOT="$REPO/tutorial"; export PDSF_TUTO_ROOT
. "$REPO/tutorial/lib/scenario.sh"
. "$REPO/tutorial/lib/recording.sh"

t "step checks judge the real workspace state"
( cd "$TMP" && env HOME="$TMP/home" PDSF_SRC="$REPO" PDSF_TUTO_DIR="$TMP/ws-check" PDSF_TUTO_SETUP_ONLY=y sh "$TUTO" ) </dev/null >/dev/null 2>&1
export PDSF_TUTO_SRC="$REPO" PDSF_TUTO_WORKSPACE="$TMP/ws-check"
assert_not "the install check fails before the install" tuto_run_check "$SCEN/01-build-the-factory/01-install"
tuto_run_action "$SCEN/01-build-the-factory/01-install" >"$TMP/install-action.log" 2>&1
assert "the install action runs install.sh for real and commits" test $? -eq 0
assert_out "$TMP/install-action.log" "@var skills=16"
assert "the install check passes after it" tuto_run_check "$SCEN/01-build-the-factory/01-install"
tuto_run_action "$SCEN/01-build-the-factory/01-install" >/dev/null 2>&1
assert "the install action is idempotent (a resumed install)" test $? -eq 0
for _s in 02-scaffold 03-context; do
  assert_not "the $_s check fails before the agent ran" tuto_run_check "$SCEN/01-build-the-factory/$_s"
done
for _s in 01-grill-with-docs 02-to-spec 03-to-tickets 04-implement 05-tests; do
  assert_not "the bonus $_s check fails before the agent ran" tuto_run_check "$SCEN/02-use-the-factory/$_s"
done

t "every recording is a real run, in the documented format"
for _s in $(tuto_recorded_steps); do
  _id=$(tuto_step_id "$_s")
  assert "$_id: the transcript names its step" test "$(rec_meta "$_s" step)" = "$_id"
  assert "$_id: format 1" test "$(rec_meta "$_s" format)" = 1
  for _k in command branch recorded recorder pdsf harness; do
    assert "$_id: the transcript records its $_k" test -n "$(rec_meta "$_s" $_k)"
  done
  assert "$_id: recorded by a real agent (Claude Code …)" sh -c 'printf "%s" "$1" | grep -q "^Claude Code [0-9]"' _ "$(rec_meta "$_s" recorder)"
  _n=$(rec_turn_count "$_s")
  assert "$_id: the first turn types the step's command" sh -c 'case "$1" in "$2"*) exit 0;; *) exit 1;; esac' _ "$(rec_turn_text "$_s" 1)" "$(rec_meta "$_s" command)"
  assert "$_id: the agent has the last word" test "$(rec_turn_role "$_s" "$_n")" = agent
  assert "$_id: no machine-specific path leaked into the recording" sh -c "! grep -rqE '/tmp/|/home/|/Users/' '$_s/recording'"
done
assert "chapter one's recordings are kept" test "$(tuto_recorded_steps | grep -c 01-build-the-factory)" -eq 3
assert "the bonus chapter has its 4 recordings" test "$(tuto_recorded_steps | grep -c 02-use-the-factory)" -eq 4
assert "the bonus recordings hold 2 learner answers in all (2–3 allowed)" test "$(cat "$SCEN"/02-use-the-factory/*/recording/transcript.md | grep -c '^<!-- pdsf-choices: ')" -eq 2
assert "the bonus ran in one agent session, each skill typed alone" sh -c 'for s in 02-to-spec 03-to-tickets 04-implement; do [ "$(sed -n "s/^session: //p" "$1/$s/recording/transcript.md")" = continued ] || exit 1; done' _ "$SCEN/02-use-the-factory"

t "the recording library parses turns, choices and the replay keys"
FAKE="$TMP/fake-step"
mkdir -p "$FAKE/recording/files/notes"
cat >"$FAKE/recording/transcript.md" <<'EOF'
---
step: 09-fake/01-step
command: /fake
branch: integration/fake
commit: Fake work
session: new
via: feature/fake
merge: Merge feature/fake
branches: extra/one
removed: gone.txt
format: 1
---

# Recording — fake

<!-- pdsf-turn: learner -->
### You

/fake

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(ls)

Question?

### Not a turn heading

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Second option | Third option -->
### You

The recorded answer.

<!-- pdsf-turn: agent -->
### Agent

Done.
EOF
printf 'note\n' >"$FAKE/recording/files/notes/n.md"
assert "4 turns" test "$(rec_turn_count "$FAKE")" -eq 4
assert "roles" test "$(rec_turn_role "$FAKE" 1)$(rec_turn_role "$FAKE" 2)$(rec_turn_role "$FAKE" 3)" = learneragentlearner
assert "a learner turn's text" test "$(rec_turn_text "$FAKE" 1)" = /fake
assert "an agent turn keeps its tool lines and sub-headings" test "$(rec_turn_text "$FAKE" 2 | tr '\n' '~')" = "⏺ Bash(ls)~~Question?~~### Not a turn heading~"
assert "the answer comes without its choices line" test "$(rec_turn_text "$FAKE" 3)" = "The recorded answer."
assert "the alternative answers" test "$(rec_turn_choices "$FAKE" 3 | tr '\n' '~')" = "Second option~Third option~"
assert "an open question has no choices" test -z "$(rec_turn_choices "$FAKE" 1)"
assert "the recorded files" test "$(rec_files "$FAKE")" = notes/n.md
REPLAY="$TMP/replay-ws"
mkdir -p "$REPLAY" && git -C "$REPLAY" init -q && printf 'x\n' >"$REPLAY/gone.txt"
git -C "$REPLAY" add -A && git -C "$REPLAY" -c user.name=t -c user.email=t@t commit -q -m init
( PDSF_TUTO_WORKSPACE="$REPLAY"; rec_apply "$FAKE" ) >/dev/null 2>&1
assert "rec_apply ends on the recorded branch" test "$(git -C "$REPLAY" symbolic-ref --short HEAD)" = integration/fake
assert "rec_apply commits on the via branch, merged --no-ff" sh -c "[ \"\$(git -C '$REPLAY' log -1 --format=%s)\" = 'Merge feature/fake' ] && [ \"\$(git -C '$REPLAY' log -1 --format=%s feature/fake)\" = 'Fake work' ]"
assert "rec_apply writes the files and removes the removed ones" sh -c "[ -f '$REPLAY/notes/n.md' ] && [ ! -e '$REPLAY/gone.txt' ] && [ -z \"\$(git -C '$REPLAY' status --porcelain)\" ]"
assert "rec_apply creates the other branches" git -C "$REPLAY" show-ref --verify --quiet refs/heads/extra/one

# ---------------------------------------------------------------------------- recorder

t "the recorder drives an agent turn by turn and writes the recording (fake agent)"
SRC=$(fake_src recorder)
REC="$SRC/tutorial/maintainers/record/record.sh"
cat >"$TMP/bin/fake-agent" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/fake-agent.calls"
mkdir -p notes && printf 'written by the fake agent\n' > notes/health.md
printf '%s\n' '{"type":"system","subtype":"init","session_id":"fake-42","model":"fake-model","claude_code_version":"9.9.9"}'
printf '%s\n' "{\"type\":\"assistant\",\"parent_tool_use_id\":null,\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"cd \$(pwd -P) && git status\"}}]}}"
printf '%s\n' '{"type":"assistant","parent_tool_use_id":"sub","message":{"content":[{"type":"text","text":"subagent noise"}]}}'
printf '%s\n' '{"type":"assistant","parent_tool_use_id":null,"message":{"content":[{"type":"text","text":"All **green**. Fix anything?"}]}}'
printf '%s\n' '{"type":"result","session_id":"fake-42","is_error":false}'
EOF
chmod +x "$TMP/bin/fake-agent"
STEP=01-build-the-factory/04-verify-factory
R="$SRC/tutorial/scenario/$STEP"
sh "$REC" steps >"$TMP/rec-steps.log" 2>&1
assert "steps: lists the recorded steps" test "$(head -n 1 "$TMP/rec-steps.log")" = 01-build-the-factory/02-scaffold
HOME="$TMP/home" sh "$REC" prepare "$STEP" "$TMP/rec-ws" >"$TMP/rec.log" 2>&1
assert "prepare: a fresh workspace, installed, with the earlier steps replayed" sh -c "git -C '$TMP/rec-ws' show develop:CONTEXT.md | grep -q Belt && [ -L '$TMP/rec-ws/.claude/skills' ]"
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$REC" turn "$TMP/rec-ws" /verify-factory >"$TMP/rec-turn.log" 2>&1
assert "turn: prints the agent's answer" grep -q 'Fix anything?' "$TMP/rec-turn.log"
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$REC" turn "$TMP/rec-ws" --choices "Yes, fix it | Show me first" "No, thanks." >>"$TMP/rec-turn.log" 2>&1
assert "the first turn starts a session" sh -c "head -n 1 '$TMP/fake-agent.calls' | grep -q '^-p /verify-factory --output-format' && ! head -n 1 '$TMP/fake-agent.calls' | grep -q -- --resume"
assert "the next turn resumes it" sh -c "sed -n 2p '$TMP/fake-agent.calls' | grep -q -- '--resume fake-42'"
sh "$REC" finish "$STEP" "$TMP/rec-ws" >>"$TMP/rec.log" 2>&1
assert "finish: the step's check passes on the recorded state" test $? -eq 0
assert "finish: 4 turns" test "$(rec_turn_count "$R")" -eq 4
assert "finish: the command and the title are kept" sh -c "[ \"\$(PDSF_TUTO_ROOT='$SRC/tutorial'; . '$SRC/tutorial/lib/scenario.sh'; tuto_meta '$R/recording/transcript.md' command)\" = /verify-factory ] && grep -q '^# Recording — Check the factory' '$R/recording/transcript.md'"
assert "finish: the learner's answer" test "$(rec_turn_text "$R" 3)" = "No, thanks."
assert "finish: its alternatives" test "$(rec_turn_choices "$R" 3 | tr '\n' '~')" = "Yes, fix it~Show me first~"
assert "finish: tool calls shown as run from the workspace" sh -c "grep -qx '⏺ Bash(git status)' '$R/recording/transcript.md'"
assert "finish: subagent traffic left out" sh -c "! grep -q 'subagent noise' '$R/recording/transcript.md'"
assert "finish: the recorder and its agent are recorded" test "$(rec_meta "$R" recorder)" = "Claude Code 9.9.9, fake-model"
assert "finish: the produced files are in files/" test -f "$R/recording/files/notes/health.md"
assert "finish: what the agent left is committed, so the next step starts from it" sh -c "[ -z \"\$(git -C '$TMP/rec-ws' status --porcelain)\" ]"
assert "finish: no workspace path leaks" sh -c "! grep -rqF '$TMP' '$R/recording'"
: >"$TMP/fake-agent.calls"
HOME="$TMP/home" sh "$REC" prepare "$STEP" "$TMP/rec-ws2" >/dev/null 2>&1
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$REC" run "$STEP" "$TMP/rec-ws2" >"$TMP/rec-run.log" 2>&1
assert "run: re-records the step from its recorded answers" test $? -eq 0
assert "run: the agent got the same two learner turns" sh -c "[ \"\$(wc -l < '$TMP/fake-agent.calls' | tr -d ' ')\" -eq 2 ] && sed -n 2p '$TMP/fake-agent.calls' | grep -q '^-p No, thanks\.'"
assert "run: the alternatives are kept" test "$(rec_turn_choices "$R" 3 | tr '\n' '~')" = "Yes, fix it~Show me first~"

# ---------------------------------------------------------------------------- install.sh contract

t "install.sh installs nothing from the tutorial into a project"
mkdir -p "$TMP/project"
PDSF_SRC="$REPO" PDSF_HARNESS=claude PDSF_MONOREPO=n sh "$REPO/install.sh" "$TMP/project" </dev/null >"$TMP/install.log" 2>&1
assert "install.sh exits 0" test $? -eq 0
assert "no tutorial file in the project" sh -c "[ -z \"\$(find '$TMP/project' -iname '*tutorial*')\" ] && ! grep -rqi 'tutorial' '$TMP/project'"
assert "nothing tutorial-related under skills/" sh -c "[ -z \"\$(find '$REPO/skills' -iname '*tutorial*')\" ] && ! grep -rqi 'pdsf-tutorial\|blackbelt' '$REPO/skills'"
assert "the same skill set as skills/" test "$(ls "$TMP/project/.agents/skills" | tr '\n' ' ')" = "$(ls "$REPO/skills" | tr '\n' ' ')"

t "install.sh: PDSF_HARNESS keeps its values"
mkdir -p "$TMP/p-generic" "$TMP/p-claude" "$TMP/p-bad"
PDSF_SRC="$REPO" PDSF_HARNESS=generic PDSF_MONOREPO=n sh "$REPO/install.sh" "$TMP/p-generic" </dev/null >/dev/null 2>&1
assert "generic: .agents only" sh -c "[ -f '$TMP/p-generic/.agents/skills/tdd/SKILL.md' ] && [ ! -e '$TMP/p-generic/.claude' ] && [ ! -e '$TMP/p-generic/CLAUDE.md' ]"
PDSF_SRC="$REPO" PDSF_HARNESS=claude PDSF_MONOREPO=n sh "$REPO/install.sh" "$TMP/p-claude" </dev/null >/dev/null 2>&1
assert "claude: .agents + .claude symlinks" sh -c "[ \"\$(readlink '$TMP/p-claude/.claude/skills')\" = ../.agents/skills ] && [ \"\$(readlink '$TMP/p-claude/CLAUDE.md')\" = AGENTS.md ]"
PDSF_SRC="$REPO" PDSF_HARNESS=emacs PDSF_MONOREPO=n sh "$REPO/install.sh" "$TMP/p-bad" </dev/null >"$TMP/p-bad.log" 2>&1
assert_not "an unknown harness is refused" test $? -eq 0

t "install.sh: the harness prompt names its outcomes"
if command -v script >/dev/null 2>&1 && script -qec true /dev/null >/dev/null 2>&1; then
  mkdir -p "$TMP/p-tty"
  printf '2\n' | script -qec "env PDSF_SRC='$REPO' PDSF_MONOREPO=n sh '$REPO/install.sh' '$TMP/p-tty'" /dev/null >"$TMP/p-tty.log" 2>&1
  assert_out "$TMP/p-tty.log" "[1] .agents "
  assert_out "$TMP/p-tty.log" "[2] .agents + .claude symlinks"
  assert "answering 2 installs the .claude overlay" test -L "$TMP/p-tty/.claude/skills"
else
  assert "prompt text names .agents + .claude symlinks" grep -qF '[2] .agents + .claude symlinks' "$REPO/install.sh"
fi
assert "docs/INSTALL.md shows the same options" sh -c "grep -qF '[1] .agents ' '$REPO/docs/INSTALL.md' && grep -qF '[2] .agents + .claude symlinks' '$REPO/docs/INSTALL.md'"

# ---------------------------------------------------------------------------- docs

t "the READMEs are up to date"
assert "README has the tutorial command" grep -qF 'tutorial/tutorial.sh | sh' "$REPO/README.md"
assert "README mentions PDSF_REF" grep -qF 'PDSF_REF' "$REPO/README.md"
assert_not "README no longer talks about tutorial modes" grep -qiE 'mode (A1|A2|B)|skill guide|guide skill|tapes /pdsf-tutorial' "$REPO/README.md"
for _h in "## Scenario format" "## Scripted input" "## Recordings" "PDSF_REF"; do
  assert "tutorial README: $_h" grep -qF "$_h" "$REPO/tutorial/README.md"
done

# ---------------------------------------------------------------------------- summary

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
