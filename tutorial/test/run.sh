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

# ---------------------------------------------------------------------------- mode B: real agent

t "mode B (real agent) is shipped: it copies the guide skill into the workspace, and only there"
tuto ws-b "$TMP/b.log" PDSF_TUTO_MODE=b PDSF_TUTO_SKIP_CH3=y
assert "tutorial exits 0" test $? -eq 0
WS="$TMP/ws-b"; G="$WS/.agents/skills/pdsf-tutorial"
assert_out "$TMP/b.log" "Real agent  (b)"
assert_out "$TMP/b.log" "✓ the install is committed"
assert "the guide skill is in .agents/skills/" test -f "$G/SKILL.md"
assert "it is the pdsf-tutorial skill" test "$(sed -n 's/^name: //p' "$G/SKILL.md")" = pdsf-tutorial
assert "the Claude layout sees it through .claude/skills" test -f "$WS/.claude/skills/pdsf-tutorial/SKILL.md"
assert "its lesson plan comes with it" sh -c "[ -f '$G/tuto.sh' ] && [ -f '$G/lib/scenario.sh' ] && [ -f '$G/scenario/01-build-the-factory/02-scaffold/check.sh' ]"
assert "no recording comes with it (nothing is replayed)" test -z "$(find "$G/scenario" -name recording)"
assert "the guide is git-excluded: the working tree stays clean" sh -c "[ -z \"\$(git -C '$WS' status --porcelain)\" ]"
assert "the guide is not committed" test -z "$(git -C "$WS" ls-files .agents/skills/pdsf-tutorial)"
assert "the learner stays on develop" test "$(git -C "$WS" symbolic-ref --short HEAD)" = develop
assert "the learner's answers are kept for the guide" sh -c "grep -qx PDSF_TUTO_SKIP_CH3=y '$G/tutorial.env' && grep -qx PDSF_TUTO_SKIP_CH2=n '$G/tutorial.env' && grep -qx PDSF_TUTO_HARNESS=claude '$G/tutorial.env'"
assert "the rest of .agents/skills is exactly what install.sh installed" test "$(ls "$WS/.agents/skills" | grep -vx pdsf-tutorial | tr '\n' ' ')" = "$(ls "$REPO/skills" | tr '\n' ' ')"
assert_out "$TMP/b.log" "cd $WS"
assert_out "$TMP/b.log" "     claude"
assert_out "$TMP/b.log" "/pdsf-tutorial"
assert_out "$TMP/b.log" "Read .agents/skills/pdsf-tutorial/SKILL.md and follow it."
assert_out "$TMP/b.log" "Skipped chapter(s): 3."
assert_out "$TMP/b.log" "Where to look next"
assert "the guide's source lives in the tutorial, not under skills/" sh -c "[ -z \"\$(find '$REPO/skills' -name 'pdsf-tutorial*')\" ] && [ -f '$REPO/tutorial/modes/b-real-agent/pdsf-tutorial/SKILL.md' ]"

t "mode B with the generic layout"
tuto ws-b-generic "$TMP/b-generic.log" PDSF_TUTO_HARNESS=generic PDSF_TUTO_MODE=b
assert "tutorial exits 0" test $? -eq 0
assert "the guide is in .agents/skills/" test -f "$TMP/ws-b-generic/.agents/skills/pdsf-tutorial/SKILL.md"
assert "no .claude overlay" test ! -e "$TMP/ws-b-generic/.claude"
assert_not "no claude command suggested" grep -qx '     claude' "$TMP/b-generic.log"
assert_out "$TMP/b-generic.log" "Read .agents/skills/pdsf-tutorial/SKILL.md and follow it."

t "the guide's tuto.sh: plan, next, show, action, check, skip"
GT="sh $G/tuto.sh"
$GT plan >"$TMP/plan.log" 2>&1
assert "plan runs" test $? -eq 0
assert_out "$TMP/plan.log" "[x] 01-build-the-factory/01-install"
assert_out "$TMP/plan.log" "[ ] 01-build-the-factory/02-scaffold"
assert_out "$TMP/plan.log" "Chapter 3 — Go further  (skipped)"
assert "plan lists every step" test "$(grep -c '^  \[' "$TMP/plan.log")" -eq "$(find "$REPO/tutorial/scenario" -name step.md | wc -l | tr -d ' ')"
assert "next is the scaffold" test "$($GT next)" = 01-build-the-factory/02-scaffold
$GT show 1.2 >"$TMP/show.log" 2>&1
assert_out "$TMP/show.log" "# Scaffold the factory"
assert_out "$TMP/show.log" "Command: /build-factory"
assert_out "$TMP/show.log" "## What you do"
assert_out "$TMP/show.log" "## Under the hood"
assert "a full step id works too" sh -c "$GT show 02-use-the-factory/04-implement | grep -qF 'Command: /implement'"
assert_not "an unknown step is refused" $GT show 9.9
$GT action 2.1 >"$TMP/b-action.log" 2>&1
assert_out "$TMP/b-action.log" "Belt US-1 [user] Submit my belt for sensei validation"
assert_not "the scaffold check fails before the agent ran" $GT check 1.2
assert "a failed check is not recorded" test "$($GT next)" = 01-build-the-factory/02-scaffold
mkdir -p "$WS/docs/agents" "$WS/docs/adr"
printf 'Tool: markdown, under business-backlog/\n' >"$WS/docs/agents/business-backlog.md"
printf 'Tickets live in .scratch/\n' >"$WS/docs/agents/issue-tracker.md"
for _p in triage-labels domain us-format; do printf 'x\n' >"$WS/docs/agents/$_p.md"; done
printf '\n## Agent skills\n' >>"$WS/AGENTS.md"
printf '# CONTEXT\n' >"$WS/CONTEXT.md"
assert "the scaffold check passes once scaffolded, from any directory" sh -c "cd '$WS/src' && $GT check 1.2"
assert "a passed check is recorded: next is the context" test "$($GT next)" = 01-build-the-factory/03-context
assert_not "the context check fails on a stub CONTEXT.md" $GT check 1.3
assert "the chapter text is shown" sh -c "$GT chapter 2 | grep -qF 'Chapter 2 — Use the factory'"
assert_not "chapter 1 cannot be skipped" $GT skip 1 y
assert "chapter 2 can be skipped" $GT skip 2 y
assert "a skipped chapter shows in the plan" sh -c "$GT plan | grep -qF 'Chapter 2 — Use the factory  (skipped)'"
assert "and un-skipped" sh -c "$GT skip 2 n && ! $GT plan | grep -qF 'Chapter 2 — Use the factory  (skipped)'"
assert_not "the guide's files never show in git status" sh -c "git -C '$WS' status --porcelain | grep -q pdsf-tutorial"

t "the guide keeps working once the fetched PDSF source is gone"
SRC=$(fake_src gone)
cp -R "$REPO/tutorial/modes/." "$SRC/tutorial/modes/"
( cd "$TMP" && env PDSF_SRC="$SRC" PDSF_TUTO_DIR=ws-b-gone PDSF_TUTO_PAUSE=n PDSF_TUTO_MODE=b PDSF_TUTO_SKIP_CH2=y PDSF_TUTO_SKIP_CH3=y sh "$SRC/tutorial/tutorial.sh" ) </dev/null >/dev/null 2>&1
rm -rf "$SRC"
GG="$TMP/ws-b-gone/.agents/skills/pdsf-tutorial"
assert "plan still runs" sh "$GG/tuto.sh" plan
assert "the install is recorded as done" sh -c "sh '$GG/tuto.sh' plan | grep -qF '[x] 01-build-the-factory/01-install'"
assert_not "checks still run (and judge the workspace)" sh "$GG/tuto.sh" check 1.3
assert "chapters 2 and 3 are skipped in the plan" sh -c "[ \"\$(sh '$GG/tuto.sh' plan | grep -c '(skipped)')\" -eq 2 ]"

t "the guide skill: portable, and it covers every agent step"
GS="$REPO/tutorial/modes/b-real-agent/pdsf-tutorial/SKILL.md"
assert_not "no harness-specific tool or output style" grep -qiE 'AskUserQuestion|TodoWrite|output.style|Skill tool|subagent_type|Claude Code' "$GS"
for _s in "$REPO"/tutorial/scenario/*/*/step.md; do
  _d=${_s%/step.md}
  [ "$(sed -n 's/^kind: //p' "$_s")" = agent ] || continue
  _id="${_d%/*}"; _id="${_id##*/}/${_d##*/}"
  assert "the guide has hints for $_id" grep -qF "$_id" "$GS"
done
assert "the guide quotes the check's ✓/✗ lines verbatim" grep -qF 'quote its ✓/✗ lines verbatim' "$GS"
assert "the guide says the install is committed on main, develop created from it" grep -qF 'committed the install on **`main`**' "$GS"
assert "the PDO recipe is documented, as optional" grep -qF '## Mode B from a shared PDO instance (optional)' "$REPO/tutorial/README.md"
assert "the mode documents its guide" grep -qF 'tuto.sh' "$REPO/tutorial/modes/b-real-agent/mode.md"

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
