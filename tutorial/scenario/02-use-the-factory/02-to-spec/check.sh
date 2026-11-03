. "$PDSF_TUTO_ROOT/lib/check.sh"

check_any "a spec exists on the technical backlog (.scratch/<feature>/SPEC.md)" .scratch/*/SPEC.md
check_that "the spec keeps the business reference (Belt US-1)" sh -c 'grep -qi "belt us-1" .scratch/*/SPEC.md'
check_done
