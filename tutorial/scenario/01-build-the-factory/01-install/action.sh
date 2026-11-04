# Install PDSF for real into the workspace (layout: .agents + .claude symlinks, no question asked),
# from the resolved PDSF source, then commit the install. Runs in the workspace.
#
# Prints a short, real summary for the learner; `@var name=value` lines are not shown, they feed
# the coach's numbers ({skills}).
set -u
_log=$(git rev-parse --git-dir)/pdsf-install.log
_version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$PDSF_TUTO_SRC/.claude-plugin/plugin.json" 2>/dev/null | head -n 1)
if ! PDSF_SRC="$PDSF_TUTO_SRC" PDSF_HARNESS=claude PDSF_MONOREPO=n \
    sh "$PDSF_TUTO_SRC/install.sh" "$PDSF_TUTO_WORKSPACE" </dev/null >"$_log" 2>&1; then
  cat "$_log"
  exit 1
fi
_skills=$(ls .agents/skills | wc -l | tr -d ' ')
printf '%s\n' "PDSF installer · ${_version:-?}"
printf '%s\n' "✓ $_skills skills → .agents/skills  (linked in .claude/skills)"
printf '%s\n' "✓ AGENTS.md  + PDSF block · CLAUDE.md → AGENTS.md"
_git() {
  if [ -n "$(git config user.email 2>/dev/null)" ]; then git "$@"; else
    git -c user.name="PDSF Tutorial" -c user.email="tutorial@pdsf.invalid" "$@"; fi
}
_git add -A || exit 1
# A resumed install (the learner quit right after it) has nothing left to commit.
_git diff --cached --quiet || _git commit -q -m "Install PDSF ${_version:-}" </dev/null || exit 1
printf '%s\n' "✓ commit  $(git rev-parse --short HEAD) $(git log -1 --format=%s)"
printf '%s\n' "@var skills=$_skills"
