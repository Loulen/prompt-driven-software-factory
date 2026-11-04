---
step: 02-use-the-factory/02-to-spec
command: /to-spec
branch: integration/BELT-US-1-submit-belt-for-validation
commit: BELT-US-1 spec: submit a belt for a sensei's decision
session: continued
via:
merge:
branches:
removed:
recorded: 2026-11-04
recorder: Claude Code 2.1.317, claude-opus-5-5
pdsf: b3d45f4
harness: claude
format: 1
---

# Recording — Write the spec (`/to-spec`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and
re-recording procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/to-spec

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(cat docs/agents/issue-tracker.md docs/agents/triage-labels.md; ls -R .scratch 2>/dev/null…)
⏺ Bash(mkdir -p .scratch/belt-submission && cat > .scratch/belt-submission/SPEC.md <<'EOF')
⏺ Bash(f=business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md; sed -i 's/^Status: …)

I've written the spec at `.scratch/belt-submission/SPEC.md` (`Status: ready-for-agent`) and committed it as `a5493c9` on `integration/BELT-US-1-submit-belt-for-validation`.

- **Tests:** I used the two test seams that already exist, as you'd asked me to decide. The `Blackbelt` domain tests cover all four rules, including rule 4, which can only be reached there. The CLI tests cover the command contract against the seed data. There is no new seam.
- **What the spec fixes:**
  - Command: `submit <belt> <consultant>`.
  - Check order: ownership first, then status, then no objective, then remaining objectives.
  - Rule 1 refusal: `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`, with several objectives separated by `; `.
  - Success output: `B-3: NEED_VALIDATION`.
  - No sensei is named and no extra data is recorded.
- **Feature Path:** it runs the four acceptance criteria on a fresh state, then has Margaret decide on B-3. The full request → mentor → objectives → submit → decide journey is flagged as a candidate Happy Path for the integration → develop MR.
- **Business backlog:** BELT-US-1 is now `In design`. That's the documented move once grilling is done and the technical counterpart exists.

Next step: `/to-tickets` to break the spec into tickets. I expect a single vertical-slice ticket, since the domain operation and the CLI command are small and ship together.
