. "$PDSF_TUTO_ROOT/lib/check.sh"

for _port in business-backlog issue-tracker triage-labels domain us-format; do
  check_file "docs/agents/$_port.md"
done
check_grep docs/agents/business-backlog.md 'business-backlog/' "the business backlog is the local business-backlog/ folder"
check_grep docs/agents/issue-tracker.md '\.scratch' "the technical backlog is local markdown under .scratch/"
check_grep AGENTS.md '^## Agent skills' "AGENTS.md carries the ## Agent skills block"
check_file CONTEXT.md "a CONTEXT.md stub exists"
check_dir docs/adr
check_done
