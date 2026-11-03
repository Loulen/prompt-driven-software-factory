# PDSF Tutorial — mode a1: narrated replay (see mode.md).
#
# Run by tutorial.sh in the workspace, after the setup, with the PDSF_TUTO_* environment. Agent
# steps are replayed from their recording and flagged SIMULATED; everything else runs for real.
set -u

. "$PDSF_TUTO_ROOT/lib/scenario.sh"
. "$PDSF_TUTO_ROOT/lib/recording.sh"

# ---------------------------------------------------------------------------- rendering

WIDTH=$(tuto_width)

# The frame of a simulated replay: every line of it starts with a bar, so the learner always sees
# where the agent's (recorded) work starts and stops.
SIM="  ${_TUTO_D}│${_TUTO_R} "
sim_say() { printf '%s%s\n' "$SIM" "$*"; }

sim_turn() {
  sim_say ""
  if [ "$1" = learner ]; then
    printf '%s\n' "$2" | sed '1s/^/**you ›** /' | tuto_md "$WIDTH" "$SIM"
  else
    sim_say "${_TUTO_B}agent ›${_TUTO_R}"
    printf '%s\n' "$2" | tuto_md "$WIDTH" "$SIM  "
  fi
}

# ---------------------------------------------------------------------------- steps

STEPS=0; SIMULATED=0

replay() {
  _rp_step=$1
  tuto_has_recording "$_rp_step" || tuto_die "no recording for $(tuto_step_id "$_rp_step"): this PDSF version cannot replay it."
  _rp_before=$(rec_git rev-parse HEAD)
  _rp_from=$(rec_git symbolic-ref --short -q HEAD)

  tuto_say ""
  printf '  %s┌─ SIMULATED ─%s %s\n' "$_TUTO_B" "$_TUTO_R" "replay of a real \`$(tuto_step_command "$_rp_step")\` session, recorded $(rec_meta "$_rp_step" recorded)"
  sim_say "${_TUTO_D}No agent runs now, no token is spent: you read what the agent did in that run"
  sim_say "($(rec_meta "$_rp_step" recorder)). On your project, the agent does this work for real.${_TUTO_R}"
  [ "$(rec_meta "$_rp_step" session)" = continued ] && \
    sim_say "${_TUTO_D}Same agent session as the previous step: the learner just typed the next command.${_TUTO_R}"
  _rp_n=$(rec_turn_count "$_rp_step"); _rp_i=1
  while [ "$_rp_i" -le "$_rp_n" ]; do
    _rp_role=$(rec_turn_role "$_rp_step" "$_rp_i")
    sim_turn "$_rp_role" "$(rec_turn_text "$_rp_step" "$_rp_i")"
    if [ "$_rp_role" = agent ] && [ "$_rp_i" -lt "$_rp_n" ]; then
      tuto_pause "  │ Enter: the learner answers…"
    fi
    _rp_i=$((_rp_i + 1))
  done
  sim_say ""
  if [ -n "$(rec_files "$_rp_step")$(rec_meta "$_rp_step" removed)" ]; then
    printf '  %s└─ SIMULATED ─%s %s\n' "$_TUTO_B" "$_TUTO_R" "applying the files the agent wrote in that run"
  else
    printf '  %s└─ SIMULATED ─%s %s\n' "$_TUTO_B" "$_TUTO_R" "end of the replay: that run wrote no file"
  fi
  rec_apply "$_rp_step" || tuto_die "applying the recording of $(tuto_step_id "$_rp_step") failed."
  SIMULATED=$((SIMULATED + 1))

  _rp_to=$(rec_git symbolic-ref --short -q HEAD)
  tuto_say ""
  tuto_say "What changed in your workspace (real git output):"
  if [ "$_rp_to" != "$_rp_from" ]; then
    tuto_say "  branch: $_rp_from → $_rp_to"
  else
    tuto_say "  branch: $_rp_to"
  fi
  if [ "$(rec_git rev-parse HEAD)" = "$_rp_before" ]; then
    tuto_say "  no file changed: this skill only reads and reports."
  else
    rec_git log --format='  commit: %h %s' "$_rp_before..HEAD"
    rec_git diff --stat=$((WIDTH - 4)) "$_rp_before" HEAD | sed 's/^/  /'
  fi
}

play_step() {
  _ps_step=$1; _ps_num=$2
  _ps_kind=$(tuto_step_kind "$_ps_step")
  _ps_cmd=$(tuto_step_command "$_ps_step")
  case "$_ps_kind" in
    setup) _ps_tag="setup · ran for real" ;;
    agent) _ps_tag="agent step · SIMULATED" ;;
    *) _ps_tag="reading" ;;
  esac
  tuto_say ""
  tuto_rule "Step $_ps_num — $(tuto_step_title "$_ps_step")  [$_ps_tag]"
  if [ -n "$_ps_cmd" ]; then
    tuto_say ""
    if [ "$_ps_kind" = setup ]; then
      tuto_say "You would type, in your project's terminal:"
      tuto_bold "  \$ $_ps_cmd"
    else
      tuto_say "You would type, in your agent's session (Claude Code, Copilot, Cursor…):"
      tuto_bold "  > $_ps_cmd"
    fi
  fi
  tuto_say ""
  tuto_bold "What you do"
  tuto_section "$_ps_step/step.md" "What you do" | tuto_md "$WIDTH" "  "
  tuto_say ""
  tuto_bold "Under the hood"
  tuto_section "$_ps_step/step.md" "Under the hood" | tuto_md "$WIDTH" "  "

  if [ "$_ps_kind" = setup ]; then
    tuto_say ""
    tuto_say "The tutorial already ran this for real, before the mode menu."
  elif tuto_has_action "$_ps_step"; then
    tuto_say ""
    tuto_say "Runs for real:"
    _ps_out=$(tuto_run_action "$_ps_step" 2>&1); _ps_rc=$?
    printf '%s\n' "$_ps_out" | sed 's/^/  /'
    [ "$_ps_rc" -eq 0 ] || tuto_die "the action of $(tuto_step_id "$_ps_step") failed."
  fi
  [ "$_ps_kind" = agent ] && replay "$_ps_step"

  tuto_say ""
  tuto_say "Check (runs for real, on your workspace):"
  tuto_run_check "$_ps_step" ||
    tuto_die "the check of $(tuto_step_id "$_ps_step") failed: the workspace is not in the state this step leads to (see the ✗ lines above)."
  STEPS=$((STEPS + 1))
  tuto_say ""
  tuto_pause
}

# ---------------------------------------------------------------------------- main

tuto_rule "Mode A1 — Narrated replay"
cat <<EOF
You read along as Blackbelt gets its factory, step by step. For each step: the command you would
type, what you do, what happens under the hood, then the result and its check.

  * Deterministic work (the install, git, the tests, every check) runs for REAL in your workspace.
  * Agent work is ${_TUTO_B}SIMULATED${_TUTO_R}: replayed from a recording of a real run of the PDSF skill on
    this same project. It is framed with │ and headed ┌─ SIMULATED ─. No agent runs, no token.
EOF

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
  _k=0
  for _step in $(tuto_steps "$_chapter"); do
    _k=$((_k + 1))
    play_step "$_step" "$_n.$_k"
  done
done

tuto_rule "Narrated replay complete"
tuto_say "$STEPS steps played, every check green; $SIMULATED of them simulated from recordings (0 tokens)."
tuto_say "Your workspace now holds what a real run leaves: look around it, run \`node --test\`."
