# PDSF Tutorial — mode B, real agent (run by tutorial.sh after the setup; see mode.md).
#
# Copies the guide skill pdsf-tutorial into the workspace, and only there (ADR-0006), with the
# scenario it follows (the PDSF source is deleted when tutorial.sh exits), then tells the learner
# how to start their harness and invoke it. The real work happens in the harness, not here.
set -u

. "$PDSF_TUTO_ROOT/lib/scenario.sh"

MODE_DIR="$PDSF_TUTO_ROOT/modes/b-real-agent"
GUIDE_REL=".agents/skills/pdsf-tutorial"
GUIDE="$PDSF_TUTO_WORKSPACE/$GUIDE_REL"
INSTALL_STEP="$PDSF_TUTO_SCENARIO/01-build-the-factory/01-install"

tuto_rule "Mode B — real agent"
cat <<'EOF'
Nothing is simulated here. Your own agent runs the real PDSF skills on Blackbelt, and a guide skill,
/pdsf-tutorial, walks you through the scenario: for each step it explains what you do and what
happens under the hood, has you type the real command, then checks the result in the workspace.
This spends tokens: chapter 1 is one grilling session plus two short skill runs; chapter 2 (up to
/implement of one ticket) costs several times that.

EOF

# ---------------------------------------------------------------------------- step 1.1: the install

tuto_bold "Chapter 1, step 1 — $(tuto_step_title "$INSTALL_STEP")  (done by the setup)"
tuto_say "The entry script ran the real install.sh into your workspace. Re-checking it:"
tuto_run_check "$INSTALL_STEP" || tuto_die "the install check failed (see the ✗ lines above)."
tuto_say ""

# ---------------------------------------------------------------------------- the guide skill

rm -rf "$GUIDE"
mkdir -p "$GUIDE" || tuto_die "cannot create $GUIDE"
cp "$MODE_DIR/pdsf-tutorial/SKILL.md" "$MODE_DIR/pdsf-tutorial/tuto.sh" "$GUIDE/" \
  && cp -R "$PDSF_TUTO_ROOT/lib" "$GUIDE/lib" \
  && cp -R "$PDSF_TUTO_SCENARIO" "$GUIDE/scenario" \
  || tuto_die "cannot copy the guide skill into $GUIDE"
# Nothing is replayed in this mode: the guide never sees a recording.
find "$GUIDE/scenario" -type d -name recording -prune -exec rm -rf {} +

{
  printf '# The learner'"'"'s tutorial answers, read by tuto.sh (PDSF_TUTO_* set/unset rule: see tutorial/README.md).\n'
  printf 'PDSF_TUTO_HARNESS=%s\n' "$PDSF_TUTO_HARNESS"
  printf 'PDSF_TUTO_SKIP_CH2=%s\n' "${PDSF_TUTO_SKIP_CH2:-n}"
  printf 'PDSF_TUTO_SKIP_CH3=%s\n' "${PDSF_TUTO_SKIP_CH3:-n}"
} >"$GUIDE/tutorial.env"
: >"$GUIDE/.progress"

# The guide is a tutorial file, not part of the factory: keep it out of git, locally.
_exclude=$(git -C "$PDSF_TUTO_WORKSPACE" rev-parse --git-path info/exclude 2>/dev/null) \
  || tuto_die "the workspace is not a git repo"
case "$_exclude" in /*) ;; *) _exclude="$PDSF_TUTO_WORKSPACE/$_exclude" ;; esac
mkdir -p "$(dirname "$_exclude")"
grep -qxF "/$GUIDE_REL/" "$_exclude" 2>/dev/null || printf '/%s/\n' "$GUIDE_REL" >>"$_exclude"

# Record the install as played.
sh "$GUIDE/tuto.sh" check 1.1 >/dev/null || tuto_die "the guide skill does not run in the workspace"

tuto_bold "The guide skill is in your workspace"
tuto_say "  $GUIDE_REL/   (git-excluded: it is the tutorial's, not your factory's)"
if [ "$PDSF_TUTO_HARNESS" = claude ]; then
  tuto_say "  .claude/skills/pdsf-tutorial/   (the same folder, through the .claude/skills symlink)"
fi
tuto_say ""

# ---------------------------------------------------------------------------- hand over

tuto_rule "Now, start your agent"
cat <<EOF
1. Go to your workspace and start your harness there (Claude Code, Copilot, Cursor, Codex…):

     cd $PDSF_TUTO_WORKSPACE
EOF
if [ "$PDSF_TUTO_HARNESS" = claude ]; then
  tuto_say "     claude"
else
  tuto_say "     <your agent's command, or open the folder in your editor's agent>"
fi
cat <<'EOF'

2. Type:

     /pdsf-tutorial

   If your agent cannot load a skill with a slash, ask it instead:
     "Read .agents/skills/pdsf-tutorial/SKILL.md and follow it."

The guide resumes where you left off: type /pdsf-tutorial again any time, in a new session too.
EOF
_skipped=""
for _c in $(tuto_chapters); do
  tuto_chapter_skipped "$_c" && _skipped="$_skipped $(tuto_chapter_number "$_c")"
done
if [ -n "$_skipped" ]; then
  tuto_say ""
  tuto_say "Skipped chapter(s):$_skipped. Ask the guide if you change your mind."
fi
exit 0
