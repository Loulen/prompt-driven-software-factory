#!/bin/sh
# PDSF Tutorial — test suite. Plays the entry script non-interactively (PDSF_TUTO_* + PDSF_SRC = this
# checkout) in temp dirs, and asserts what the learner sees and the workspace state.
#
#   sh tutorial/test/run.sh
#
# Needs sh, git, node 18+. Never writes into the checkout.
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
TUTO="$REPO/tutorial/tutorial.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

PASS=0; FAIL=0; CURRENT=""

t() { CURRENT=$1; printf '%s\n' "• $1"; }
ok() { PASS=$((PASS + 1)); }
ko() { FAIL=$((FAIL + 1)); printf '  FAIL [%s] %s\n' "$CURRENT" "$1"; }
assert() { _what=$1; shift; if "$@" >/dev/null 2>&1; then ok; else ko "$_what"; fi; }
assert_not() { _what=$1; shift; if "$@" >/dev/null 2>&1; then ko "$_what"; else ok; fi; }
assert_out() { if grep -qF -- "$2" "$1"; then ok; else ko "output lacks: $2"; fi; }

# tuto DIR LOG [VAR=value…] — play the tutorial from this checkout, no tty, pauses off.
tuto() {
  _dir=$1; _log=$2; shift 2
  ( cd "$TMP" && env PDSF_SRC="$REPO" PDSF_TUTO_DIR="$_dir" PDSF_TUTO_PAUSE=n "$@" sh "$TUTO" ) </dev/null >"$_log" 2>&1
}

# A copy of the PDSF source, to try the mode menu against modes this checkout doesn't ship.
fake_src() {
  _fs="$TMP/src-$1"
  mkdir -p "$_fs"
  ( cd "$REPO" && tar cf - --exclude=.git --exclude=.pdo . ) | ( cd "$_fs" && tar xf - )
  rm -rf "$_fs/tutorial/modes"/*
  printf '%s' "$_fs"
}

# ---------------------------------------------------------------------------- setup

t "setup with the .agents + .claude symlinks layout (the default)"
tuto ws-claude "$TMP/claude.log" PDSF_TUTO_MODE=
WS="$TMP/ws-claude"
assert "tutorial exits 0" test $? -eq 0
assert "workspace is a git repo" test -d "$WS/.git"
assert "workspace starts with the fixture's initial commit" sh -c "git -C '$WS' log --format=%s main | grep -qx 'Blackbelt (lite): initial commit'"
assert "the install is committed" sh -c "git -C '$WS' log -1 --format=%s main | grep -q 'Install PDSF'"
assert "develop exists and is checked out" sh -c "[ \"\$(git -C '$WS' symbolic-ref --short HEAD)\" = develop ]"
assert "the working tree is clean" sh -c "[ -z \"\$(git -C '$WS' status --porcelain)\" ]"
assert "the fixture tests pass with no npm install" sh -c "cd '$WS' && [ ! -d node_modules ] && node --test"
assert "every skill is installed" sh -c "for s in '$REPO'/skills/*/; do s=\${s%/}; [ -f '$WS'/.agents/skills/\${s##*/}/SKILL.md ] || exit 1; done"
assert "AGENTS.md is wired" grep -qF '<!-- PDSF:BEGIN -->' "$WS/AGENTS.md"
assert ".claude/skills -> ../.agents/skills" sh -c "[ \"\$(readlink '$WS/.claude/skills')\" = ../.agents/skills ]"
assert "CLAUDE.md -> AGENTS.md" sh -c "[ \"\$(readlink '$WS/CLAUDE.md')\" = AGENTS.md ]"
assert "the seed story is in the business backlog" test -f "$WS/business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md"
assert_not "the seed story is NOT implemented in the fixture" grep -qi submit "$WS/src/blackbelt.js"
assert_out "$TMP/claude.log" "[2] .agents + .claude symlinks"
assert_out "$TMP/claude.log" "[1] .agents "
assert_out "$TMP/claude.log" "✓ node --test"
assert_out "$TMP/claude.log" "✓ CLAUDE.md -> AGENTS.md (symlink)"
assert_out "$TMP/claude.log" "Where to look next"

t "setup with the .agents (generic) layout"
tuto ws-generic "$TMP/generic.log" PDSF_TUTO_HARNESS=1 PDSF_TUTO_MODE=
WS="$TMP/ws-generic"
assert "tutorial exits 0" test $? -eq 0
assert "skills in .agents/skills" test -f "$WS/.agents/skills/build-factory/SKILL.md"
assert "AGENTS.md is wired" grep -qF '<!-- PDSF:BEGIN -->' "$WS/AGENTS.md"
assert "no .claude overlay" test ! -e "$WS/.claude"
assert "no CLAUDE.md" test ! -e "$WS/CLAUDE.md"
assert_out "$TMP/generic.log" "✓ no .claude overlay (generic layout)"

t "harness names: generic / claude are accepted, junk is refused"
tuto ws-h-generic "$TMP/h1.log" PDSF_TUTO_HARNESS=generic PDSF_TUTO_MODE=
assert "generic accepted" test $? -eq 0
tuto ws-h-claude "$TMP/h2.log" PDSF_TUTO_HARNESS=claude PDSF_TUTO_MODE=
assert "claude accepted" test -L "$TMP/ws-h-claude/CLAUDE.md"
tuto ws-h-bad "$TMP/h3.log" PDSF_TUTO_HARNESS=vim PDSF_TUTO_MODE=
assert_not "junk refused" test $? -eq 0
assert_out "$TMP/h3.log" "unknown harness layout 'vim'"

t "the entry script works piped into sh (curl … | sh)"
( cd "$TMP" && env PDSF_SRC="$REPO" PDSF_TUTO_DIR=ws-piped PDSF_TUTO_MODE= PDSF_TUTO_PAUSE=n sh ) <"$TUTO" >"$TMP/piped.log" 2>&1
assert "piped run exits 0" test $? -eq 0
assert "piped run installs PDSF" test -f "$TMP/ws-piped/.agents/skills/build-factory/SKILL.md"
assert_out "$TMP/piped.log" "Where to look next"

t "the default workspace is ./pdsf-tutorial-workspace"
mkdir -p "$TMP/default-cwd"
( cd "$TMP/default-cwd" && env PDSF_SRC="$REPO" PDSF_TUTO_MODE= PDSF_TUTO_PAUSE=n sh "$TUTO" ) </dev/null >"$TMP/default.log" 2>&1
assert "workspace created in the current dir" test -d "$TMP/default-cwd/pdsf-tutorial-workspace/.git"

t "a non-empty workspace is refused, and left untouched"
mkdir -p "$TMP/busy" && printf 'mine\n' >"$TMP/busy/notes.txt"
tuto busy "$TMP/busy.log" PDSF_TUTO_MODE=
assert_not "refused" test $? -eq 0
assert_out "$TMP/busy.log" "is not empty"
assert "the learner's file is untouched" sh -c "[ \"\$(cat '$TMP/busy/notes.txt')\" = mine ] && [ \"\$(ls -A '$TMP/busy')\" = notes.txt ]"

t "an empty existing directory is accepted"
mkdir -p "$TMP/empty"
tuto empty "$TMP/empty.log" PDSF_TUTO_MODE=
assert "accepted" test -d "$TMP/empty/.git"

t "the tutorial never writes into the PDSF source"
SRC=$(fake_src inside)
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR="$SRC/ws" PDSF_TUTO_MODE= PDSF_TUTO_PAUSE=n sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/inside.log" 2>&1
assert_not "a workspace inside the source is refused" test $? -eq 0
assert "nothing was created in the source" test ! -e "$SRC/ws"
assert_out "$TMP/inside.log" "never writes there"
assert "the checkout has no workspace nor CLI state" sh -c "[ ! -e '$REPO/pdsf-tutorial-workspace' ] && [ ! -e '$REPO/tutorial/fixture/blackbelt-lite/.blackbelt-state.json' ]"

t "--help documents the PDSF_TUTO_* variables"
sh "$TUTO" --help >"$TMP/help.log" 2>&1
assert "--help exits 0" test $? -eq 0
for _v in PDSF_TUTO_DIR PDSF_TUTO_HARNESS PDSF_TUTO_MODE PDSF_TUTO_SKIP_CH2 PDSF_TUTO_SKIP_CH3 PDSF_TUTO_PAUSE PDSF_SRC; do
  assert_out "$TMP/help.log" "$_v"
done

# ---------------------------------------------------------------------------- mode menu

t "no mode shipped: the menu says so and the tutorial exits cleanly"
SRC=$(fake_src none)
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-nomode PDSF_TUTO_PAUSE=n sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/nomode.log" 2>&1
assert "exits 0" test $? -eq 0
assert_out "$TMP/nomode.log" "No tutorial mode is shipped yet"

t "shipped modes are listed and dispatched with the PDSF_TUTO_* contract"
SRC=$(fake_src modes)
for _id in a1-first b-second; do
  mkdir -p "$SRC/tutorial/modes/$_id"
  printf -- '---\ntitle: Mode %s\nsummary: The %s fake mode.\n---\n' "$_id" "$_id" >"$SRC/tutorial/modes/$_id/mode.md"
  cat >"$SRC/tutorial/modes/$_id/play.sh" <<'EOF'
{
  echo "mode=$PDSF_TUTO_MODE"
  echo "cwd=$(pwd -P)"
  echo "ws=$PDSF_TUTO_WORKSPACE"
  echo "harness=$PDSF_TUTO_HARNESS"
  echo "skip2=$PDSF_TUTO_SKIP_CH2"
  echo "skip3=$PDSF_TUTO_SKIP_CH3"
  echo "pause=$PDSF_TUTO_PAUSE"
  echo "root=$PDSF_TUTO_ROOT"
  echo "src=$PDSF_TUTO_SRC"
} > "$PDSF_TUTO_WORKSPACE/.played"
exit 7
EOF
done
mkdir -p "$SRC/tutorial/modes/c-unfinished"   # no play.sh: not shipped
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-mode PDSF_TUTO_PAUSE=n PDSF_TUTO_MODE=b PDSF_TUTO_SKIP_CH2=y sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/mode.log" 2>&1
assert "the mode's exit code is the tutorial's" test $? -eq 7
P="$TMP/ws-mode/.played"
assert_out "$TMP/mode.log" "[1] Mode a1-first  (a1)"
assert_out "$TMP/mode.log" "[2] Mode b-second  (b)"
assert_not "a mode folder without play.sh is not offered" grep -q unfinished "$TMP/mode.log"
assert "the mode is picked by id" grep -qx 'mode=b' "$P"
assert "the mode runs in the workspace" grep -qx "cwd=$TMP/ws-mode" "$P"
assert "PDSF_TUTO_WORKSPACE" grep -qx "ws=$TMP/ws-mode" "$P"
assert "PDSF_TUTO_HARNESS is normalised" grep -qx 'harness=claude' "$P"
assert "PDSF_TUTO_SKIP_CH2" grep -qx 'skip2=y' "$P"
assert "PDSF_TUTO_SKIP_CH3 defaults to n" grep -qx 'skip3=n' "$P"
assert "PDSF_TUTO_PAUSE" grep -qx 'pause=n' "$P"
assert "PDSF_TUTO_ROOT" grep -qx "root=$SRC/tutorial" "$P"
assert "PDSF_TUTO_SRC" grep -qx "src=$SRC" "$P"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-mode-n PDSF_TUTO_PAUSE=n PDSF_TUTO_MODE=1 sh "$SRC/tutorial/tutorial.sh" ) </dev/null >/dev/null 2>&1
assert "the mode is picked by number" grep -qx 'mode=a1' "$TMP/ws-mode-n/.played"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-mode-d PDSF_TUTO_PAUSE=n sh "$SRC/tutorial/tutorial.sh" ) </dev/null >/dev/null 2>&1
assert "with no answer, the first mode is the default" grep -qx 'mode=a1' "$TMP/ws-mode-d/.played"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-mode-x PDSF_TUTO_PAUSE=n PDSF_TUTO_MODE=zz sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/mode-x.log" 2>&1
assert_not "an unknown mode is refused" test $? -eq 0
assert_out "$TMP/mode-x.log" "unknown tutorial mode 'zz'"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-mode-e PDSF_TUTO_PAUSE=n PDSF_TUTO_MODE= sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/mode-e.log" 2>&1
assert "an empty PDSF_TUTO_MODE stops after the setup" test ! -e "$TMP/ws-mode-e/.played"
assert_out "$TMP/mode-e.log" "No mode chosen"

# ---------------------------------------------------------------------------- scenario

t "the scenario: 3 chapters, every step with English learner text and a check"
SCEN="$REPO/tutorial/scenario"
export PDSF_TUTO_ROOT="$REPO/tutorial"
. "$REPO/tutorial/lib/scenario.sh"
_chapters=$(tuto_chapters)
assert "three chapters" test "$(printf '%s\n' "$_chapters" | wc -l | tr -d ' ')" -eq 3
assert "chapter 1 is not skippable" test "$(tuto_meta "$SCEN/01-build-the-factory/chapter.md" skippable)" = false
assert "chapter 2 is skippable" test "$(tuto_meta "$SCEN/02-use-the-factory/chapter.md" skippable)" = true
assert "chapter 3 is skippable" test "$(tuto_meta "$SCEN/03-go-further/chapter.md" skippable)" = true
_commands=""
for _c in $_chapters; do
  assert "${_c##*/} has a title" test -n "$(tuto_meta "$_c/chapter.md" title)"
  for _s in $(tuto_steps "$_c"); do
    _id=$(tuto_step_id "$_s")
    assert "$_id has a title" test -n "$(tuto_step_title "$_s")"
    assert "$_id has a known kind" sh -c "case '$(tuto_step_kind "$_s")' in setup|agent|reading) exit 0;; *) exit 1;; esac"
    assert "$_id says what you do" test -n "$(tuto_section "$_s/step.md" "What you do")"
    assert "$_id says what happens under the hood" test -n "$(tuto_section "$_s/step.md" "Under the hood")"
    assert "$_id has a check" test -f "$_s/check.sh"
    if [ "$(tuto_step_kind "$_s")" = agent ]; then
      assert "$_id (agent) names its command" test -n "$(tuto_step_command "$_s")"
      assert "$_id (agent) has a recording slot" test -d "$_s/recording"
    fi
    _commands="$_commands $(tuto_step_command "$_s" | sed -n 's#^/\([a-z-]*\).*#\1#p')"
  done
done
assert "chapter 1 runs /build-factory (scaffold, context) then /verify-factory" test "$(tuto_steps "$SCEN/01-build-the-factory" | while read -r s; do tuto_step_command "$s"; done | grep '^/' | tr '\n' ' ')" = "/build-factory /build-factory /verify-factory "
assert "chapter 2 runs /grill-with-docs → /to-spec → /to-tickets → /implement" test "$(tuto_steps "$SCEN/02-use-the-factory" | while read -r s; do tuto_step_command "$s"; done | tr '\n' ' ')" = "/grill-with-docs /to-spec /to-tickets /implement "
for _cmd in $_commands; do
  assert "/$_cmd is a real PDSF skill" test -f "$REPO/skills/$_cmd/SKILL.md"
done

t "step checks judge the real workspace state"
WS="$TMP/ws-claude"
export PDSF_TUTO_SRC="$REPO" PDSF_TUTO_WORKSPACE="$WS" PDSF_TUTO_HARNESS=claude
assert "install check passes on a fresh workspace" tuto_run_check "$SCEN/01-build-the-factory/01-install"
check_as_generic() ( PDSF_TUTO_HARNESS=generic; export PDSF_TUTO_HARNESS; tuto_run_check "$1" )
assert_not "the install check fails against the wrong layout" check_as_generic "$SCEN/01-build-the-factory/01-install"
for _s in 02-scaffold 03-context; do
  assert_not "the $_s check fails before the agent ran" tuto_run_check "$SCEN/01-build-the-factory/$_s"
done
for _s in 01-grill-with-docs 02-to-spec 03-to-tickets 04-implement; do
  assert_not "the $_s check fails before the agent ran" tuto_run_check "$SCEN/02-use-the-factory/$_s"
done
for _s in $(tuto_steps "$SCEN/03-go-further"); do
  assert "$(tuto_step_id "$_s") check passes" tuto_run_check "$_s"
done
tuto_run_action "$SCEN/02-use-the-factory/01-grill-with-docs" >"$TMP/action.log" 2>&1
assert "the grilling step's action runs" test $? -eq 0
assert_out "$TMP/action.log" "Belt US-1 [user] Submit my belt for sensei validation"
assert "a step action leaves the workspace clean" sh -c "[ -z \"\$(git -C '$WS' status --porcelain)\" ]"

t "a scaffolded workspace passes the scaffold check"
mkdir -p "$WS/docs/agents" "$WS/docs/adr"
printf 'Tool: markdown, under business-backlog/\n' >"$WS/docs/agents/business-backlog.md"
printf 'Tickets live in .scratch/\n' >"$WS/docs/agents/issue-tracker.md"
for _p in triage-labels domain us-format; do printf 'x\n' >"$WS/docs/agents/$_p.md"; done
printf '\n## Agent skills\n' >>"$WS/AGENTS.md"
printf '# CONTEXT\n' >"$WS/CONTEXT.md"
assert "scaffold check passes" tuto_run_check "$SCEN/01-build-the-factory/02-scaffold"
assert_not "a stub CONTEXT.md does not pass the context check" tuto_run_check "$SCEN/01-build-the-factory/03-context"

# ---------------------------------------------------------------------------- recordings

. "$REPO/tutorial/lib/recording.sh"

t "every agent step has a recording of a real run, in the documented format"
for _s in $(for _c in $(tuto_chapters); do tuto_steps "$_c"; done); do
  [ "$(tuto_step_kind "$_s")" = agent ] || continue
  _id=$(tuto_step_id "$_s")
  assert "$_id has a recording" tuto_has_recording "$_s"
  tuto_has_recording "$_s" || continue
  assert "$_id: the transcript names its step" test "$(rec_meta "$_s" step)" = "$_id"
  assert "$_id: the transcript names the step's command" test "$(rec_meta "$_s" command)" = "$(tuto_step_command "$_s")"
  assert "$_id: format 1" test "$(rec_meta "$_s" format)" = 1
  for _k in branch recorded recorder pdsf harness; do
    assert "$_id: the transcript records its $_k" test -n "$(rec_meta "$_s" $_k)"
  done
  assert "$_id: recorded by a real agent (Claude Code …)" sh -c 'printf "%s" "$1" | grep -q "^Claude Code [0-9]"' _ "$(rec_meta "$_s" recorder)"
  assert "$_id: session is new or continued" sh -c 'case "$1" in new|continued) exit 0;; *) exit 1;; esac' _ "$(rec_meta "$_s" session)"
  _n=$(rec_turn_count "$_s")
  assert "$_id: at least one exchange" test "$_n" -ge 2
  assert "$_id: the first turn types the step's command" sh -c 'case "$1" in "$2"*) exit 0;; *) exit 1;; esac' _ "$(rec_turn_text "$_s" 1)" "$(tuto_step_command "$_s")"
  assert "$_id: the agent has the last word" test "$(rec_turn_role "$_s" "$_n")" = agent
  _i=1; _alt=0
  while [ "$_i" -le "$_n" ]; do
    _r=$(rec_turn_role "$_s" "$_i")
    [ $((_i % 2)) -eq 1 ] && [ "$_r" != learner ] && _alt=1
    [ $((_i % 2)) -eq 0 ] && [ "$_r" != agent ] && _alt=1
    [ -n "$(rec_turn_text "$_s" "$_i")" ] || _alt=1
    _i=$((_i + 1))
  done
  assert "$_id: turns alternate learner / agent, none empty" test "$_alt" -eq 0
  assert "$_id: no machine-specific path leaked into the recording" sh -c "! grep -rqE '/tmp/|/home/|/Users/' '$_s/recording'"
done
assert "/to-spec continues the grilling's agent session" test "$(rec_meta "$SCEN/02-use-the-factory/02-to-spec" session)" = continued
assert "the scaffold recording keeps alternative answers for its questions" test -n "$(rec_turn_choices "$SCEN/01-build-the-factory/02-scaffold" 3)"
assert "the implement recording works on a feature branch merged into the integration branch" sh -c 'printf "%s" "$1" | grep -q "^feature/"' _ "$(rec_meta "$SCEN/02-use-the-factory/04-implement" via)"

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

# ---------------------------------------------------------------------------- mode A1

# A `claude` on PATH that leaves a mark: mode A1 must never call an agent.
mkdir -p "$TMP/bin"
printf '#!/bin/sh\necho "$*" >> "%s/claude-called"\nexit 1\n' "$TMP" >"$TMP/bin/claude"
chmod +x "$TMP/bin/claude"

t "mode A1 is in the menu"
assert_out "$TMP/claude.log" "[1] Narrated replay  (a1)"

t "mode A1, non-interactive, every chapter: every step and every check pass, zero tokens"
tuto ws-a1 "$TMP/a1.log" PATH="$TMP/bin:$PATH" PDSF_TUTO_MODE=a1 PDSF_TUTO_SKIP_CH2=n PDSF_TUTO_SKIP_CH3=n
assert "the tutorial exits 0" test $? -eq 0
WS="$TMP/ws-a1"
assert "no agent was called (zero tokens)" test ! -e "$TMP/claude-called"
assert_out "$TMP/a1.log" "12 steps played, every check green; 7 of them simulated from recordings (0 tokens)."
assert "every agent step is flagged SIMULATED" test "$(grep -c '^  ┌─ SIMULATED ─ replay of a real' "$TMP/a1.log")" -eq 7
assert "every agent step closes its SIMULATED frame" test "$(grep -c '^  └─ SIMULATED ─' "$TMP/a1.log")" -eq 7
assert "no check failed" sh -c "! grep -q '✗' '$TMP/a1.log'"
for _cmd in "> /build-factory" "> /verify-factory" "> /grill-with-docs" "> /to-spec" "> /to-tickets" "> /implement" "\$ curl -fsSL"; do
  assert_out "$TMP/a1.log" "$_cmd"
done
assert "every step says what you do and what happens under the hood" sh -c "[ \"\$(grep -c '^What you do' '$TMP/a1.log')\" -eq 12 ] && [ \"\$(grep -c '^Under the hood' '$TMP/a1.log')\" -eq 12 ]"
assert_out "$TMP/a1.log" "you › /build-factory"
assert_out "$TMP/a1.log" "agent ›"
assert_out "$TMP/a1.log" "What changed in your workspace (real git output):"
assert_out "$TMP/a1.log" "Runs for real:"
assert_out "$TMP/a1.log" "Belt US-1 [user] Submit my belt for sensei validation"
assert_out "$TMP/a1.log" "Where to look next"
assert "chapter 1: both backlogs are local markdown" sh -c "grep -q 'business-backlog/' '$WS/docs/agents/business-backlog.md' && grep -q '.scratch' '$WS/docs/agents/issue-tracker.md'"
assert "chapter 1: CONTEXT.md and the founding ADRs are on develop" sh -c "git -C '$WS' show develop:CONTEXT.md | grep -q Belt && git -C '$WS' ls-tree --name-only develop docs/adr/ | grep -q '\.md$'"
assert "chapter 2: the story's integration branch is checked out" sh -c "git -C '$WS' symbolic-ref --short HEAD | grep -qi '^integration/belt-us-1'"
assert "chapter 2: tickets ready for an agent on the local tracker" sh -c "grep -l 'ready-for-agent' '$WS'/.scratch/*/tickets/*.md"
assert "chapter 2: the business story links back to its ticket" grep -q '^## Comments' "$WS/business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md"
assert "chapter 2: the ticket was merged from its feature branch" sh -c "git -C '$WS' log -1 --format=%s | grep -q '^Merge feature/'"
assert "chapter 2: node --test is green" sh -c "cd '$WS' && node --test"
assert "chapter 2: the submission rule is tested" grep -q 'submit' "$WS/test/blackbelt.test.js"
( cd "$WS" && node src/cli.js reset && node src/cli.js submit B-3 linus ) >"$TMP/submit-ok.log" 2>&1
assert "Linus submits his belt: it awaits the sensei's validation" grep -q 'B-3: NEED_VALIDATION' "$TMP/submit-ok.log"
( cd "$WS" && node src/cli.js submit B-2 ada ) >"$TMP/submit-ko.log" 2>&1
assert "Ada's submission is refused (exit 2)" test $? -eq 2
assert "the refusal names the remaining objective" grep -q 'Run a refactoring workshop' "$TMP/submit-ko.log"
( cd "$WS" && node src/cli.js reset ) >/dev/null 2>&1
assert "the workspace is clean at the end" sh -c "[ -z \"\$(git -C '$WS' status --porcelain)\" ]"

t "mode A1 with the .agents (generic) layout, chapters 2 and 3 skipped"
tuto ws-a1-generic "$TMP/a1-generic.log" PATH="$TMP/bin:$PATH" PDSF_TUTO_HARNESS=generic PDSF_TUTO_MODE=a1 PDSF_TUTO_SKIP_CH2=y PDSF_TUTO_SKIP_CH3=y
assert "the tutorial exits 0" test $? -eq 0
assert_out "$TMP/a1-generic.log" "4 steps played, every check green; 3 of them simulated from recordings (0 tokens)."
assert_out "$TMP/a1-generic.log" "Skipping Chapter 2"
assert_out "$TMP/a1-generic.log" "Skipping Chapter 3"
assert_not "no chapter 2 step was played" grep -q 'Step 2\.' "$TMP/a1-generic.log"
assert "chapter 1's state is reached" sh -c "cd '$TMP/ws-a1-generic' && git show develop:CONTEXT.md | grep -q Belt && [ ! -e CLAUDE.md ]"
assert "no integration branch without chapter 2" sh -c "[ -z \"\$(git -C '$TMP/ws-a1-generic' branch --list 'integration/*')\" ]"
assert "no agent was called (zero tokens)" test ! -e "$TMP/claude-called"
assert_out "$TMP/a1-generic.log" "Where to look next"

t "mode A1 stops on a failing step check"
SRC=$(fake_src a1-broken)
cp -R "$REPO/tutorial/modes/." "$SRC/tutorial/modes/"
rm "$SRC/tutorial/scenario/01-build-the-factory/03-context/recording/files/CONTEXT.md"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-a1-broken PDSF_TUTO_MODE=a1 PDSF_TUTO_SKIP_CH2=y PDSF_TUTO_SKIP_CH3=y PDSF_TUTO_PAUSE=n sh "$SRC/tutorial/tutorial.sh" ) </dev/null >"$TMP/a1-broken.log" 2>&1
assert_not "the tutorial fails" test $? -eq 0
assert_out "$TMP/a1-broken.log" "the check of 01-build-the-factory/03-context failed"
assert_not "it does not go on to the next step" grep -q 'Step 1.4' "$TMP/a1-broken.log"

# ---------------------------------------------------------------------------- recorder

t "the recorder drives an agent turn by turn and writes the recording (fake agent)"
SRC=$(fake_src recorder)
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
sh "$SRC/tutorial/record/record.sh" prepare "$STEP" "$TMP/rec-ws" >"$TMP/rec.log" 2>&1
assert "prepare: a fresh workspace with the earlier steps replayed" sh -c "git -C '$TMP/rec-ws' show develop:CONTEXT.md | grep -q Belt"
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$SRC/tutorial/record/record.sh" turn "$TMP/rec-ws" /verify-factory >"$TMP/rec-turn.log" 2>&1
assert "turn: prints the agent's answer" grep -q 'Fix anything?' "$TMP/rec-turn.log"
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$SRC/tutorial/record/record.sh" turn "$TMP/rec-ws" --choices "Yes, fix it | Show me first" "No, thanks." >>"$TMP/rec-turn.log" 2>&1
assert "the first turn starts a session" sh -c "head -n 1 '$TMP/fake-agent.calls' | grep -q '^-p /verify-factory --output-format' && ! head -n 1 '$TMP/fake-agent.calls' | grep -q -- --resume"
assert "the next turn resumes it" sh -c "sed -n 2p '$TMP/fake-agent.calls' | grep -q -- '--resume fake-42'"
sh "$SRC/tutorial/record/record.sh" finish "$STEP" "$TMP/rec-ws" >>"$TMP/rec.log" 2>&1
assert "finish: the step's check passes on the recorded state" test $? -eq 0
assert "finish: 4 turns" test "$(rec_turn_count "$R")" -eq 4
assert "finish: the learner's answer" test "$(rec_turn_text "$R" 3)" = "No, thanks."
assert "finish: its alternatives" test "$(rec_turn_choices "$R" 3 | tr '\n' '~')" = "Yes, fix it~Show me first~"
assert "finish: tool calls shown as run from the workspace" sh -c "grep -qx '⏺ Bash(git status)' '$R/recording/transcript.md'"
assert "finish: subagent traffic left out" sh -c "! grep -q 'subagent noise' '$R/recording/transcript.md'"
assert "finish: the recorder and its agent are recorded" test "$(rec_meta "$R" recorder)" = "Claude Code 9.9.9, fake-model"
assert "finish: the produced files are in files/" test -f "$R/recording/files/notes/health.md"
assert "finish: what the agent left is committed, so the next step starts from it" sh -c "[ -z \"\$(git -C '$TMP/rec-ws' status --porcelain)\" ]"
assert "finish: no workspace path leaks" sh -c "! grep -rqF '$TMP' '$R/recording'"
: >"$TMP/fake-agent.calls"
sh "$SRC/tutorial/record/record.sh" prepare "$STEP" "$TMP/rec-ws2" >/dev/null 2>&1
PDSF_RECORD_CLAUDE="$TMP/bin/fake-agent" sh "$SRC/tutorial/record/record.sh" run "$STEP" "$TMP/rec-ws2" >"$TMP/rec-run.log" 2>&1
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

t "README links the tutorial"
assert "README has the tutorial command" grep -qF 'tutorial/tutorial.sh | sh' "$REPO/README.md"

# ---------------------------------------------------------------------------- summary

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
