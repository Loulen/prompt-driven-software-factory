. "$PDSF_TUTO_ROOT/lib/check.sh"

for _skill in "$PDSF_TUTO_SRC"/skills/*/; do
  _skill=${_skill%/}; _skill=${_skill##*/}
  [ -f ".agents/skills/$_skill/SKILL.md" ] || check_fail ".agents/skills/$_skill/SKILL.md missing"
done
check_file .agents/skills/build-factory/SKILL.md "every PDSF skill is in .agents/skills/"
check_grep AGENTS.md '<!-- PDSF:BEGIN -->' "AGENTS.md carries the PDSF block"
check_link .claude/skills ../.agents/skills
check_link CLAUDE.md AGENTS.md
check_that "the install is committed" git log -1 --format=%s -- AGENTS.md
check_that "the working tree is clean" sh -c '[ -z "$(git status --porcelain)" ]'
check_done
