# PDSF Tutorial — replay rendering library (POSIX sh, sourced — never executed).
#
# What the simulated modes show the learner, written once so they all look alike and keep the
# terminal rendering fixes (no line wider than the terminal, nothing hard-wrapped outside its
# indent): the step header and learner text, the deterministic action, the SIMULATED frame around
# replayed agent turns, and "what changed" in the workspace after a recording is applied.
# Shared by mode A1 (narrated replay) and mode A2 (simulated session, and its stand-in `claude`).
#
# Needs lib/scenario.sh and lib/recording.sh sourced first.

WIDTH=$(tuto_width)

# The frame of a simulated replay: every line of it starts with a bar, so the learner always sees
# where the agent's (recorded) work starts and stops.
SIM="  ${_TUTO_D}│${_TUTO_R} "
sim_say() { printf '%s%s\n' "$SIM" "$*"; }

# sim_note "text" — a dimmed note inside the frame, wrapped to the width.
sim_note() {
  printf '%s\n' "$1" | tuto_md "$WIDTH" "$SIM$_TUTO_D" | sed "s/\$/$_TUTO_R/"
}

# sim_open "text" / sim_close "text" — the head and foot of the frame.
sim_open()  { printf '  %s┌─ SIMULATED ─%s %s\n' "$_TUTO_B" "$_TUTO_R" "$1"; }
sim_close() { printf '  %s└─ SIMULATED ─%s %s\n' "$_TUTO_B" "$_TUTO_R" "$1"; }

# fit PREFIX — one-line items on stdin (commit subjects), each prefixed and kept within the width:
# a line that does not fit is cut (never inside a UTF-8 character) and ends with …, so the terminal
# never wraps it outside its indent. Text the learner must read whole goes through tuto_wrap.
fit() {
  LC_ALL=C awk -v w="$((WIDTH - ${#1} - 1))" -v p="$1" '
    length($0) > w + 1 { n = w; while (n > 0 && substr($0, n + 1, 1) ~ /[\200-\277]/) n--; $0 = substr($0, 1, n) "…" }
    { print p $0 }'
}

# sim_turn learner|agent "text" — one turn of a recorded session, inside the frame.
sim_turn() {
  sim_say ""
  if [ "$1" = learner ]; then
    printf '%s\n' "$2" | sed '1s/^/**you ›** /' | tuto_md "$WIDTH" "$SIM"
  else
    sim_say "${_TUTO_B}agent ›${_TUTO_R}"
    printf '%s\n' "$2" | tuto_md "$WIDTH" "$SIM  "
  fi
}

# rp_close_and_apply STEP — close the frame, saying what comes next, and apply the recording.
rp_close_and_apply() {
  sim_say ""
  if [ -n "$(rec_files "$1")$(rec_meta "$1" removed)" ]; then
    sim_close "applying the files the agent wrote in that run"
  else
    sim_close "end of the replay: that run wrote no file"
  fi
  rec_apply "$1" || tuto_die "applying the recording of $(tuto_step_id "$1") failed."
}

# rp_changes BEFORE FROM — what the last replay changed in the workspace, from real git output:
# BEFORE is the commit and FROM the branch the workspace was on before it.
rp_changes() {
  _rc_to=$(rec_git symbolic-ref --short -q HEAD)
  tuto_say ""
  tuto_say "What changed in your workspace (real git output):"
  if [ "$_rc_to" != "$2" ]; then
    tuto_say "  branch: $2 → $_rc_to"
  else
    tuto_say "  branch: $_rc_to"
  fi
  if [ "$(rec_git rev-parse HEAD)" = "$1" ]; then
    tuto_say "  no file changed: this skill only reads and reports."
  else
    rec_git log --format='commit: %h %s' "$1..HEAD" | fit "  "
    rec_git diff --stat=$((WIDTH - 4)) "$1" HEAD | sed 's/^/  /'
  fi
}

# rp_replay STEP — the narrated replay of an agent step (mode A1, and mode A2 for the steps the
# learner leaves to it): the recorded session in a SIMULATED frame, then its files applied and
# what changed.
rp_replay() {
  _rp_step=$1
  tuto_has_recording "$_rp_step" || tuto_die "no recording for $(tuto_step_id "$_rp_step"): this PDSF version cannot replay it."
  _rp_before=$(rec_git rev-parse HEAD)
  _rp_from=$(rec_git symbolic-ref --short -q HEAD)

  tuto_say ""
  sim_open "replay of a real $(tuto_step_command "$_rp_step") session, recorded $(rec_meta "$_rp_step" recorded)"
  sim_note "No agent runs now, no token is spent: you read what the agent did in that run ($(rec_meta "$_rp_step" recorder)). On your project, the agent does this work for real."
  [ "$(rec_meta "$_rp_step" session)" = continued ] && \
    sim_note "Same agent session as the previous step: the learner just typed the next command."
  _rp_n=$(rec_turn_count "$_rp_step"); _rp_i=1
  while [ "$_rp_i" -le "$_rp_n" ]; do
    _rp_role=$(rec_turn_role "$_rp_step" "$_rp_i")
    sim_turn "$_rp_role" "$(rec_turn_text "$_rp_step" "$_rp_i")"
    if [ "$_rp_role" = agent ] && [ "$_rp_i" -lt "$_rp_n" ]; then
      tuto_pause "  │ Enter: the learner answers…"
    fi
    _rp_i=$((_rp_i + 1))
  done
  rp_close_and_apply "$_rp_step"
  rp_changes "$_rp_before" "$_rp_from"
}

# rp_step_tag STEP -> the tag of the step's kind, for its header.
rp_step_tag() {
  case "$(tuto_step_kind "$1")" in
    setup) printf '%s' "setup · ran for real" ;;
    agent) printf '%s' "agent step · SIMULATED" ;;
    *) printf '%s' "reading" ;;
  esac
}

# rp_step_intro STEP NUM TAG ["lead line for an agent command"] — the step's header: its title and
# tag, the command the learner types, then What you do and Under the hood.
rp_step_intro() {
  _si_step=$1
  _si_kind=$(tuto_step_kind "$_si_step")
  _si_cmd=$(tuto_step_command "$_si_step")
  tuto_say ""
  tuto_rule "Step $2 — $(tuto_step_title "$_si_step")  [$3]"
  if [ -n "$_si_cmd" ]; then
    tuto_say ""
    if [ "$_si_kind" = setup ]; then
      tuto_say "You would type, in your project's terminal:"
      tuto_bold "  \$ $_si_cmd"
    else
      tuto_say "${4:-You would type, in your agent's session (Claude Code, Copilot, Cursor…):}"
      tuto_bold "  > $_si_cmd"
    fi
  fi
  tuto_say ""
  tuto_bold "What you do"
  tuto_section "$_si_step/step.md" "What you do" | tuto_md "$WIDTH" "  "
  tuto_say ""
  tuto_bold "Under the hood"
  tuto_section "$_si_step/step.md" "Under the hood" | tuto_md "$WIDTH" "  "
}

# rp_step_action STEP — the step's deterministic action, run for real, its output wrapped.
rp_step_action() {
  tuto_has_action "$1" || return 0
  tuto_say ""
  tuto_say "Runs for real:"
  _sa_out=$(tuto_run_action "$1" 2>&1); _sa_rc=$?
  printf '%s\n' "$_sa_out" | tuto_wrap "$WIDTH" "  "
  [ "$_sa_rc" -eq 0 ] || tuto_die "the action of $(tuto_step_id "$1") failed."
}

# rp_step_check STEP — the step's check, run for real; a failing check stops the mode.
rp_step_check() {
  tuto_say ""
  tuto_say "Check (runs for real, on your workspace):"
  tuto_run_check "$1" ||
    tuto_die "the check of $(tuto_step_id "$1") failed: the workspace is not in the state this step leads to (see the ✗ lines above)."
}
