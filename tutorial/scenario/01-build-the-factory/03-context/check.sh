. "$PDSF_TUTO_ROOT/lib/check.sh"

check_grep CONTEXT.md 'belt' "CONTEXT.md defines the domain (Belt…)"
check_grep CONTEXT.md 'mentor' "CONTEXT.md defines the mentor"
check_any "at least one foundational ADR in docs/adr/" docs/adr/*.md
check_that "the context is committed on develop" sh -c 'git show develop:CONTEXT.md | grep -qi belt'
check_done
