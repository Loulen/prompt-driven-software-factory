. "$PDSF_TUTO_ROOT/lib/check.sh"

check_any "tickets exist (.scratch/<feature>/tickets/NN-<slug>.md)" .scratch/*/tickets/[0-9]*.md
check_that "a ticket is ready for an agent" sh -c 'grep -qi "ready-for-agent" .scratch/*/tickets/[0-9]*.md'
check_grep business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md '^## Comments' "the business story links back to its tickets"
check_done
