# PDSF Tutorial — mode a2: the stand-in `claude` (see mode.md).
#
# What the learner runs when they type `claude` in the tutorial's sub-shell: a temporary `claude`
# wrapper, first on the sub-shell's PATH only, execs this script. It is NOT an agent: it replays
# the recordings of the session's agent steps (tutorial/scenario/*/*/recording/), in order. It
# recognises the step's slash command, replays the recorded agent turns, asks each recorded
# question as numbered choices (default = the recorded answer), accepts and flags off-script
# answers, then applies the recorded files exactly as mode A1 does (rec_apply). Zero tokens.
#
# Input: the learner's lines on stdin (the terminal, or a scripted session). Arguments are taken as
# the first line typed, as with `claude "/build-factory"`.
#
# Environment (set by play.sh in the wrapper): PDSF_TUTO_ROOT, PDSF_TUTO_WORKSPACE and
# PDSF_TUTO_A2_STATE, the mode's state directory:
#   steps      the session's agent steps, in order, "N.K<TAB>step dir"
#   plan       every agent step the tutorial plays, same format (for hints)
#   done       the steps played, one step dir per line (this script appends to it)
#   offscript  one line per off-script answer of the steps played (this script appends to it)
set -u

. "$PDSF_TUTO_ROOT/lib/scenario.sh"
. "$PDSF_TUTO_ROOT/lib/recording.sh"
. "$PDSF_TUTO_ROOT/lib/replay.sh"

STATE=${PDSF_TUTO_A2_STATE:?the stand-in claude only runs in the tutorial sub-shell}
touch "$STATE/done" "$STATE/offscript"
OFF_SCRIPT="simulated: a real agent would adapt, the recorded path continues"
# The step this process played last, for steps recorded in the same agent session as the previous.
LAST=""

# Echo what was typed when stdin is not a terminal, so a scripted session reads like a real one.
TTY_IN=""; [ -t 0 ] && TTY_IN=y

# dim_md "text" — dimmed text, wrapped to the width.
dim_md() { printf '%s\n' "$1" | tuto_md "$WIDTH" "$_TUTO_D" | sed "s/\$/$_TUTO_R/"; }

# ---------------------------------------------------------------------------- state

# next_step -> "N.K<TAB>step dir" of the first session step not played yet (empty: all played).
next_step() {
  while IFS= read -r _ns; do
    grep -qxF "${_ns#*	}" "$STATE/done" || { printf '%s' "$_ns"; return 0; }
  done <"$STATE/steps"
}

# recorded_command STEP -> the command as typed in the recorded run (first learner turn).
recorded_command() { rec_turn_text "$1" 1 | head -n 1; }

# ---------------------------------------------------------------------------- input

# ask "prompt" -> sets LINE to the next line typed (surrounding blanks trimmed); status 1 at the
# end of the input (Ctrl-D).
ask() {
  if [ -n "$TTY_IN" ]; then
    printf '%s' "$1"
    IFS= read -r LINE || { printf '\n'; return 1; }
  else
    IFS= read -r LINE || { printf '%s\n' "$1"; return 1; }
    printf '%s%s\n' "$1" "$LINE" | tuto_wrap "$WIDTH"
  fi
  LINE=$(printf '%s' "$LINE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  return 0
}

is_exit() {
  case "$1" in /exit|/quit|exit|quit) return 0 ;; *) return 1 ;; esac
}

goodbye() {
  tuto_say ""
  _gb=$(next_step)
  if [ -n "$_gb" ]; then
    dim_md "Leaving the simulated session. Step ${_gb%%	*} is not played yet: type \`claude\` to come back to it, or \`exit\` the sub-shell to return to the tutorial."
  else
    dim_md "Leaving the simulated session. Now type \`exit\` (or Ctrl-D) to leave the sub-shell: the tutorial then runs the checks of the steps you played, for real."
  fi
  exit 0
}

# ---------------------------------------------------------------------------- what to type

# hint ["why"] — what the session cannot answer, and what it can at this step.
hint() {
  tuto_say ""
  printf '%s\n' "**simulated session: not recorded**${1:+ — $1}" | tuto_md "$WIDTH"
  available
}

# available — the commands the session can answer at this step.
available() {
  _h=$(next_step)
  if [ -n "$_h" ]; then
    tuto_say "Available at this step (${_h%%	*}, $(tuto_step_title "${_h#*	}")):"
    recorded_command "${_h#*	}" | tuto_wrap "$WIDTH" "  "
  else
    tuto_say "This session's steps are all played. Available:"
  fi
  tuto_say "  /help   what you can type here"
  tuto_say "  /exit   leave the session (then exit the sub-shell to return to the tutorial)"
}

# where_is COMMAND -> why a recorded command is not the one to type now (empty: not recorded):
# recorded for a later step, or already played (the latest step it was played at).
where_is() {
  _wi_next=$(next_step); _wi_why=""
  while IFS= read -r _wi; do
    _wi_dir=${_wi#*	}
    [ "$(tuto_step_command "$_wi_dir")" = "$1" ] || continue
    [ "$_wi" = "$_wi_next" ] && continue
    if grep -qxF "$_wi_dir" "$STATE/done"; then
      _wi_why="$1 was already played (step ${_wi%%	*})"
    elif [ -z "$_wi_why" ]; then
      _wi_why="$1 is recorded for a later step (${_wi%%	*}): play this one first"
    fi
  done <"$STATE/plan"
  printf '%s' "$_wi_why"
}

help_text() {
  tuto_say ""
  tuto_bold "claude (simulated stand-in) — what you can type"
  tuto_md "$WIDTH" "  " <<'EOF'
* The command of the current step (below): its recorded session is replayed.
* At a question: Enter for the recorded answer, a number for one of the choices, or your own text.
  Anything but the recorded answer is accepted and flagged off-script: the recorded path continues.
* `/help` this help · `/exit` (or Ctrl-D) leave the session.
EOF
  available
}

# ---------------------------------------------------------------------------- steps

# intro STEP_LINE — the learner text of the step to play next, and its deterministic action.
intro() {
  _in_dir=${1#*	}
  rp_step_intro "$_in_dir" "${1%%	*}" "agent step · SIMULATED" "Type it here, at the claude (stand-in) prompt:"
  rp_step_action "$_in_dir"
  tuto_say ""
}

# answer STEP N — ask the learner turn N of STEP as numbered choices; status 1 if they leave.
answer() {
  _an_step=$1; _an_n=$2
  _an_rec=$(rec_turn_text "$_an_step" "$_an_n")
  _an_alts=$(rec_turn_choices "$_an_step" "$_an_n")
  sim_say ""
  printf '%s\n' "**Your answer** — Enter for 1, the recorded one; another number; or your own words:" | tuto_md "$WIDTH" "$SIM"
  {
    printf '1) %s **(recorded)**\n' "$_an_rec"
    printf '%s\n' "$_an_alts" | grep . | awk '{ printf "%d) %s\n", NR + 1, $0 }'
  } | tuto_md "$WIDTH" "$SIM  "
  _an_count=$(printf '%s\n' "$_an_alts" | grep -c .)
  ask "$SIM${_TUTO_B}›${_TUTO_R} " || return 1
  is_exit "$LINE" && return 1
  case "$LINE" in
    ""|1) _an_said=$_an_rec ;;
    *[!0-9]*) _an_said=$LINE ;;
    *)
      if [ "$LINE" -ge 2 ] && [ "$LINE" -le $((_an_count + 1)) ]; then
        _an_said=$(printf '%s\n' "$_an_alts" | grep . | sed -n "$((LINE - 1))p")
      else
        _an_said=$LINE
      fi
      ;;
  esac
  sim_turn learner "$_an_said"
  if [ "$_an_said" != "$_an_rec" ]; then
    sim_say ""
    printf '%s\n' "**⚑ off-script — $OFF_SCRIPT.**" | tuto_md "$WIDTH" "$SIM"
    printf '%s turn %s: %s\n' "$(tuto_step_id "$_an_step")" "$_an_n" "$_an_said" | tr '\n' ' ' >>"$STATE/offscript.step"
    printf '\n' >>"$STATE/offscript.step"
    sim_note "The recorded answer was: $_an_rec"
  fi
  return 0
}

# play STEP_LINE TYPED — the recorded session of a step, then its files applied.
play() {
  _pl_num=${1%%	*}; _pl_step=${1#*	}; _pl_typed=$2
  tuto_has_recording "$_pl_step" || tuto_die "no recording for $(tuto_step_id "$_pl_step"): this PDSF version cannot replay it."
  _pl_before=$(rec_git rev-parse HEAD)
  _pl_from=$(rec_git symbolic-ref --short -q HEAD)
  _pl_rec=$(recorded_command "$_pl_step")

  tuto_say ""
  sim_open "replay of a real $(tuto_step_command "$_pl_step") session, recorded $(rec_meta "$_pl_step" recorded)"
  sim_note "No agent runs, no token is spent: the agent's turns are those of that run ($(rec_meta "$_pl_step" recorder)). On your project, the agent does this work for real."
  [ "$_pl_typed" != "$_pl_rec" ] && sim_note "Recorded as: $_pl_rec"
  if [ "$(rec_meta "$_pl_step" session)" = continued ]; then
    if [ -n "$LAST" ]; then
      sim_note "Same agent session as the previous step, as in the recorded run: the agent still has its context."
    else
      sim_note "In the recorded run, this command was typed in the same session as the previous step. You started a new one: a real agent would lack that context and re-read it from the files. The recorded path continues."
    fi
  fi
  : >"$STATE/offscript.step"
  _pl_n=$(rec_turn_count "$_pl_step"); _pl_i=2
  while [ "$_pl_i" -le "$_pl_n" ]; do
    if [ "$(rec_turn_role "$_pl_step" "$_pl_i")" = agent ]; then
      sim_turn agent "$(rec_turn_text "$_pl_step" "$_pl_i")"
    elif ! answer "$_pl_step" "$_pl_i"; then
      sim_say ""
      sim_close "session left before the end of the step: nothing applied"
      goodbye
    fi
    _pl_i=$((_pl_i + 1))
  done
  trap '' INT
  rp_close_and_apply "$_pl_step"
  printf '%s\n' "$_pl_step" >>"$STATE/done"
  cat "$STATE/offscript.step" >>"$STATE/offscript"
  trap 'interrupted' INT
  rp_changes "$_pl_before" "$_pl_from"
  LAST=$_pl_step

  _pl_next=$(next_step)
  if [ -n "$_pl_next" ]; then
    tuto_say ""
    tuto_dim "Step $_pl_num played. Next:"
    intro "$_pl_next"
  else
    tuto_say ""
    printf '%s\n' "**Step $_pl_num played: that was this session's last step.** Type \`/exit\`, then \`exit\` (or Ctrl-D) to leave the sub-shell: the tutorial then runs the checks of the steps you played, for real." | tuto_md "$WIDTH"
    tuto_say ""
  fi
}

interrupted() {
  tuto_say ""
  tuto_dim "(interrupted)"
  goodbye
}
trap 'interrupted' INT

# ---------------------------------------------------------------------------- main

tuto_say ""
printf '%s✻ claude%s %s\n' "$_TUTO_B" "$_TUTO_R" "— SIMULATED stand-in, PDSF tutorial"
tuto_md "$WIDTH" "  " <<'EOF'
Not Claude Code: a stand-in that replays recorded real sessions of the PDSF skills. No agent runs,
no token is spent. It only exists in this tutorial sub-shell: your own `claude` is untouched.
`/help` what you can type · `/exit` leave.
EOF

_next=$(next_step)
if [ -z "$_next" ]; then
  tuto_say ""
  available
  goodbye
fi
tuto_say ""
intro "$_next"

_first=""
[ "$#" -gt 0 ] && _first="$*"
while :; do
  if [ -n "$_first" ]; then
    LINE=$_first; _first=""
    printf '> %s\n' "$LINE" | tuto_wrap "$WIDTH"
  else
    ask "${_TUTO_B}>${_TUTO_R} " || goodbye
  fi
  case "$LINE" in
    "") continue ;;
    /help|help) help_text; continue ;;
  esac
  is_exit "$LINE" && goodbye
  _next=$(next_step)
  _cmd=${LINE%%[[:space:]]*}
  case "$LINE" in
    /*)
      if [ -n "$_next" ] && [ "$_cmd" = "$(tuto_step_command "${_next#*	}")" ]; then
        play "$_next" "$LINE"
      else
        _why=$(where_is "$_cmd")
        hint "${_why:-no recording of $_cmd at this point of the tutorial}"
      fi
      ;;
    *) hint "the stand-in only replays the recorded commands; a real agent would answer free text" ;;
  esac
done
