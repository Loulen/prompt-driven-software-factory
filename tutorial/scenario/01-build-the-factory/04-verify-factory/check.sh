. "$PDSF_TUTO_ROOT/lib/check.sh"

check_file docs/agents/issue-tracker.md "the scaffold is present"
check_grep CONTEXT.md 'belt' "the context is filled"
check_that "develop exists (git-flow)" git show-ref --verify --quiet refs/heads/develop
check_that "the factory files are versioned (not git-ignored)" sh -c '! git check-ignore -q .agents/skills AGENTS.md CONTEXT.md docs/agents'
check_done
