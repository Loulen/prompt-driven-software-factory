. "$PDSF_TUTO_ROOT/lib/check.sh"

# Named after the business story's reference: git-flow keeps its case (integration/BELT-US-1-…).
_branch=$(git for-each-ref --format='%(refname:short)' refs/heads/integration/ | grep -i '^integration/belt-us-1' | head -n 1)
check_that "an integration/belt-us-1-… branch exists" test -n "$_branch"
check_that "the grilling output (CONTEXT.md / docs/adr/) is on it" sh -c "[ -n \"$_branch\" ] && ! git diff --quiet develop \"$_branch\" -- CONTEXT.md docs/adr"
check_done
