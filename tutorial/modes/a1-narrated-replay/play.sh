# PDSF Tutorial — mode a1: narrated replay (see mode.md).
#
# Run by tutorial.sh in the workspace, after the setup, with the PDSF_TUTO_* environment. Agent
# steps are replayed from their recording and flagged SIMULATED; everything else runs for real.
set -u

. "$PDSF_TUTO_ROOT/lib/scenario.sh"
. "$PDSF_TUTO_ROOT/lib/recording.sh"
. "$PDSF_TUTO_ROOT/lib/replay.sh"

# ---------------------------------------------------------------------------- steps

STEPS=0; SIMULATED=0

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
  if [ "$_ps_kind" = agent ]; then
    rp_replay "$_ps_step"
    SIMULATED=$((SIMULATED + 1))
  fi
  rp_step_check "$_ps_step"
  STEPS=$((STEPS + 1))
  tuto_say ""
  tuto_pause
}

# ---------------------------------------------------------------------------- main

tuto_rule "Mode A1 — Narrated replay"
tuto_md "$WIDTH" <<'EOF'
You read along as Blackbelt gets its factory, step by step. For each step: the command you would
type, what you do, what happens under the hood, then the result and its check.

  * Deterministic work (the install, git, the tests, every check) runs for REAL in your workspace.
  * Agent work is **SIMULATED**: replayed from a recording of a real run of the PDSF skill on
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
tuto_md "$WIDTH" <<EOF
$STEPS steps played, every check green; $SIMULATED of them replayed (0 tokens).

Your workspace now holds what a real run leaves: look around it, run \`node --test\`.
EOF
