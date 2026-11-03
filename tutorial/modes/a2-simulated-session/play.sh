# PDSF Tutorial — mode a2: simulated session (see mode.md).
#
# Run by tutorial.sh in the workspace, after the setup, with the PDSF_TUTO_* environment. For each
# chapter's agent steps it opens a sub-shell in the workspace where a stand-in `claude` (and only
# there) is first on PATH: the learner types `claude`, then the real slash commands, and answers the
# recorded questions. The stand-in replays the recordings of mode A1 and applies the same files, so
# the workspace ends in the same state. When the learner leaves the sub-shell, the tutorial runs
# the checks of those steps. Everything else (the install, actions, checks) runs for real, as in A1.
set -u

. "$PDSF_TUTO_ROOT/lib/scenario.sh"
. "$PDSF_TUTO_ROOT/lib/recording.sh"
. "$PDSF_TUTO_ROOT/lib/replay.sh"

MODE_DIR="$PDSF_TUTO_ROOT/modes/a2-simulated-session"

# The mode's state, and the stand-in's bin directory: outside the workspace, removed at the end.
STATE=$(mktemp -d) || tuto_die "mktemp -d failed"
trap 'rm -rf "$STATE"' EXIT
trap 'exit 130' INT TERM
: >"$STATE/plan"; : >"$STATE/done"; : >"$STATE/offscript"

# q 'text' -> text single-quoted for sh.
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# ---------------------------------------------------------------------------- the stand-in

# bin/claude: execs the stand-in with the tutorial's environment baked in, so a learner's rc file
# cannot break it. It exists only in $STATE/bin, which only the sub-shell has on its PATH.
mkdir -p "$STATE/bin" "$STATE/zdot"
{
  printf '#!/bin/sh\n'
  printf '# PDSF tutorial: the SIMULATED stand-in claude (mode a2). Not Claude Code.\n'
  printf 'PDSF_TUTO_ROOT=%s PDSF_TUTO_WORKSPACE=%s PDSF_TUTO_A2_STATE=%s\n' \
    "$(q "$PDSF_TUTO_ROOT")" "$(q "$PDSF_TUTO_WORKSPACE")" "$(q "$STATE")"
  printf 'export PDSF_TUTO_ROOT PDSF_TUTO_WORKSPACE PDSF_TUTO_A2_STATE\n'
  printf 'exec sh %s "$@"\n' "$(q "$MODE_DIR/stand-in.sh")"
} >"$STATE/bin/claude"
chmod +x "$STATE/bin/claude"

# The sub-shell's rc: the learner's own first (aliases, prompt…), then the stand-in put back first
# on PATH (an rc file may prepend the directory of the real claude), and a prompt that says so.
{
  printf 'unalias claude 2>/dev/null; unset -f claude 2>/dev/null\n'
  printf 'PATH=%s:"$PATH"; export PATH; hash -r 2>/dev/null\n' "$(q "$STATE/bin")"
  printf 'PS1="(pdsf simulated) ${PS1:-\\$ }"\n'
} >"$STATE/rc-common"
printf '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n. %s\n' "$(q "$STATE/rc-common")" >"$STATE/bashrc"
printf '[ -f "$HOME/.zshenv" ] && . "$HOME/.zshenv"\n' >"$STATE/zdot/.zshenv"
printf 'ZDOTDIR="$HOME"\n[ -f "$HOME/.zshrc" ] && . "$HOME/.zshrc"\n. %s\n' "$(q "$STATE/rc-common")" >"$STATE/zdot/.zshrc"
cp "$STATE/rc-common" "$STATE/shrc"

# ---------------------------------------------------------------------------- the sub-shell

# pending -> the session's steps not played yet, "N.K<TAB>step dir" per line.
pending() {
  while IFS= read -r _pe; do
    grep -qxF "${_pe#*	}" "$STATE/done" || printf '%s\n' "$_pe"
  done <"$STATE/steps"
}

# scripted_input -> what a learner following the recorded path types in the stand-in: each pending
# step's recorded command, Enter at each question (the recorded answer), then /exit.
scripted_input() {
  pending | while IFS= read -r _si; do
    _si_dir=${_si#*	}
    rec_turn_text "$_si_dir" 1 | head -n 1
    _si_n=$(rec_turn_count "$_si_dir"); _si_i=2
    while [ "$_si_i" -le "$_si_n" ]; do
      [ "$(rec_turn_role "$_si_dir" "$_si_i")" = learner ] && printf '\n'
      _si_i=$((_si_i + 1))
    done
  done
  printf '/exit\n'
}

# subshell CHAPTER_NUMBER — the learner's session: an interactive shell on the terminal, or, driven
# by PDSF_TUTO_A2_SESSION (or with no terminal), a script that types for them.
subshell() {
  _sub_path="$STATE/bin:$PATH"
  eval "_sub_set=\${PDSF_TUTO_A2_SESSION+x}"
  if [ "$_sub_set" != x ] && tuto_has_tty; then
    trap ':' INT
    _sub_sh=${SHELL:-/bin/sh}
    case "${_sub_sh##*/}" in
      bash) PATH=$_sub_path "$_sub_sh" --rcfile "$STATE/bashrc" -i ;;
      zsh) PATH=$_sub_path ZDOTDIR="$STATE/zdot" "$_sub_sh" -i ;;
      sh|dash|ash|ksh|mksh) PATH=$_sub_path ENV="$STATE/shrc" "$_sub_sh" -i ;;
      *) PATH=$_sub_path ENV="$STATE/shrc" /bin/sh -i ;;
    esac
    trap 'exit 130' INT
  elif [ -n "${PDSF_TUTO_A2_SESSION:-}" ]; then
    [ -f "$PDSF_TUTO_A2_SESSION" ] || tuto_die "PDSF_TUTO_A2_SESSION: no such file: $PDSF_TUTO_A2_SESSION"
    printf '%s\n' "(PDSF_TUTO_A2_SESSION: $PDSF_TUTO_A2_SESSION types for the learner)" | tuto_wrap "$WIDTH"
    PATH=$_sub_path PDSF_TUTO_A2_CHAPTER=$1 sh "$PDSF_TUTO_A2_SESSION" </dev/null
  else
    printf '%s\n' "(no terminal: the session follows the recorded path — each recorded command, Enter at each question)" | tuto_md "$WIDTH"
    scripted_input >"$STATE/session.in"
    tuto_say "\$ claude"
    PATH=$_sub_path claude <"$STATE/session.in"
    tuto_say "\$ exit"
  fi
  tuto_say ""
}

# ---------------------------------------------------------------------------- steps

STEPS=0; IN_SESSION=0; REPLAYED=0

play_step() {
  _ps_step=$1
  _ps_kind=$(tuto_step_kind "$_ps_step")
  rp_step_intro "$_ps_step" "$2" "$(rp_step_tag "$_ps_step")"
  if [ "$_ps_kind" = setup ]; then
    tuto_say ""
    tuto_say "The tutorial already ran this for real, before the mode menu."
  else
    rp_step_action "$_ps_step"
  fi
  rp_step_check "$_ps_step"
  STEPS=$((STEPS + 1))
  tuto_say ""
  tuto_pause
}

# session CHAPTER_NUMBER — the agent steps listed in $STATE/steps, played by the learner in the
# simulated session, then their checks.
session() {
  _se_cmds=$(while IFS= read -r _se; do printf '%s, ' "$(tuto_step_command "${_se#*	}")"; done <"$STATE/steps")
  tuto_say ""
  tuto_rule "Simulated session — chapter $1"
  tuto_md "$WIDTH" <<EOF
The agent steps of this chapter happen in **your terminal, as on your project**. The tutorial now
opens a sub-shell in your workspace. There, type \`claude\`, then the commands one after the other:
${_se_cmds%, }. Answer the questions the agent asks.

  * That \`claude\` is a **SIMULATED stand-in**: no agent runs, no token is spent. It replays a
    recorded real session of each skill, asks its questions as numbered choices (Enter = the
    recorded answer), and writes the files that run wrote. Any other answer is accepted and flagged.
  * It is first on PATH **only in this sub-shell** (its prompt says \`(pdsf simulated)\`): your own
    \`claude\` is untouched. Look around too: \`git log\`, \`ls\`, \`cat\` are real.
  * To leave: \`/exit\` in claude, then \`exit\` (or Ctrl-D). The tutorial then runs the checks.
EOF
  tuto_pause "Enter: open the sub-shell…"
  while :; do
    tuto_say ""
    tuto_bold "┌─ SIMULATED SESSION ─ a sub-shell in your workspace"
    subshell "$1"
    tuto_bold "└─ SIMULATED SESSION ─ back in the tutorial"
    _se_left=$(pending)
    [ -z "$_se_left" ] && break
    tuto_say ""
    tuto_say "Not played in the session yet:"
    printf '%s\n' "$_se_left" | while IFS= read -r _se; do
      tuto_say "  step ${_se%%	*}  $(tuto_step_command "${_se#*	}")  — $(tuto_step_title "${_se#*	}")"
    done
    if tuto_has_tty; then _se_def=o; else _se_def=r; fi
    _se_ans=$(tuto_ask PDSF_TUTO_A2_LEFT "[o] re-open the session · [r] replay them for you (as in mode A1) · [q] stop the tutorial ($_se_def): " "$_se_def")
    [ -n "$_se_ans" ] || _se_ans=$_se_def
    case "$_se_ans" in
      o|O) tuto_has_tty && [ -z "${PDSF_TUTO_A2_SESSION+x}" ] && continue
           tuto_dim "(no terminal to re-open the session on: replaying them for you)" ;;
      r|R) ;;
      q|Q) tuto_die "stopped with step(s) left unplayed: the workspace is in the state of the last step played." ;;
      *) tuto_die "unknown answer '$_se_ans' (o, r or q)" ;;
    esac
    printf '%s\n' "$_se_left" | while IFS= read -r _se; do
      rp_step_intro "${_se#*	}" "${_se%%	*}" "agent step · SIMULATED"
      tuto_say ""
      tuto_say "Replayed for you, as in mode A1: you left the session before this step."
      rp_step_action "${_se#*	}"
      rp_replay "${_se#*	}"
      printf '%s\n' "${_se#*	}" >>"$STATE/done"
      printf 'x\n' >>"$STATE/replayed"
      tuto_say ""
    done
    break
  done

  tuto_say ""
  tuto_rule "Chapter $1: the checks of the session's steps"
  printf '%s\n' "Each step's check runs for real, on your workspace: it judges the files and git, never the stand-in." | tuto_md "$WIDTH"
  while IFS= read -r _se; do
    tuto_say ""
    tuto_bold "Step ${_se%%	*} — $(tuto_step_title "${_se#*	}")  ($(tuto_step_command "${_se#*	}"))"
    tuto_run_check "${_se#*	}" ||
      tuto_die "the check of $(tuto_step_id "${_se#*	}") failed: the workspace is not in the state this step leads to (see the ✗ lines above)."
    STEPS=$((STEPS + 1))
  done <"$STATE/steps"
  tuto_say ""
  tuto_pause
}

# ---------------------------------------------------------------------------- main

tuto_rule "Mode A2 — Simulated session"
tuto_md "$WIDTH" <<'EOF'
You make the real gestures: for each agent step you type `claude`, then the real slash command, and
answer the agent's questions, in a sub-shell of your workspace. Zero tokens: the `claude` there is
a stand-in.

  * Deterministic work (the install, git, the tests, every check) runs for REAL in your workspace.
  * Agent work is **SIMULATED**: the stand-in replays a recording of a real run of the PDSF skill
    on this same project, framed with │ and headed ┌─ SIMULATED ─, and writes the files it wrote.
EOF

# The plan: every agent step of the chapters played, numbered as in the tutorial.
for _chapter in $(tuto_chapters); do
  tuto_chapter_skipped "$_chapter" && continue
  _n=$(tuto_chapter_number "$_chapter"); _k=0
  for _step in $(tuto_steps "$_chapter"); do
    _k=$((_k + 1))
    [ "$(tuto_step_kind "$_step")" = agent ] && printf '%s.%s\t%s\n' "$_n" "$_k" "$_step" >>"$STATE/plan"
  done
done

for _chapter in $(tuto_chapters); do
  _n=$(tuto_chapter_number "$_chapter")
  tuto_say ""
  if tuto_chapter_skipped "$_chapter"; then
    tuto_dim "Skipping $(tuto_meta "$_chapter/chapter.md" title) (you chose to skip it)."
    tuto_say ""
    continue
  fi
  tuto_rule "$(tuto_meta "$_chapter/chapter.md" title)"
  tuto_body "$_chapter/chapter.md" | tuto_md "$WIDTH"
  # Consecutive agent steps are played in one session; the other steps as in mode A1.
  : >"$STATE/steps"
  _k=0
  for _step in $(tuto_steps "$_chapter"); do
    _k=$((_k + 1))
    if [ "$(tuto_step_kind "$_step")" = agent ]; then
      printf '%s.%s\t%s\n' "$_n" "$_k" "$_step" >>"$STATE/steps"
      continue
    fi
    [ -s "$STATE/steps" ] && { session "$_n"; : >"$STATE/steps"; }
    play_step "$_step" "$_n.$_k"
  done
  [ -s "$STATE/steps" ] && session "$_n"
done

REPLAYED=$( [ -f "$STATE/replayed" ] && grep -c . "$STATE/replayed" || echo 0)
IN_SESSION=$(($(grep -c . "$STATE/done") - REPLAYED))
OFF=$(grep -c . "$STATE/offscript")
tuto_rule "Simulated session complete"
tuto_md "$WIDTH" <<EOF
$STEPS steps played, every check green; $IN_SESSION of them in the simulated session, $REPLAYED replayed for you, $OFF off-script answer(s) (0 tokens).

Your workspace now holds what a real run leaves, the same as with mode A1: look around it, run \`node --test\`.
EOF
if [ "$OFF" -gt 0 ]; then
  tuto_say ""
  tuto_say "Your off-script answers (a real agent would have adapted to them):"
  sed 's/ *$//' "$STATE/offscript" | tuto_wrap "$WIDTH" "  "
fi
