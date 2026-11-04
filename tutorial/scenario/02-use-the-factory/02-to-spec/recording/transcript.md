---
step: 02-use-the-factory/02-to-spec
command: /to-spec
branch: integration/BELT-US-1-submit-my-belt-for-sensei-validation
commit: BELT-US-1 spec: submit a belt for a sensei's decision
session: continued
via:
merge:
branches:
removed:
recorded: 2026-11-03
recorder: Claude Code 2.1.317, claude-opus-5-5
pdsf: b6456d7
harness: claude
format: 1
---

# Recording — Write the spec (`/to-spec`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/to-spec

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git status -sb; cat docs/agents/issue-tracker.md docs/agents/triage-…)

Before I write the spec, here's my proposal for where to test this. Both seams already exist, so nothing new is needed:

1. **The domain seam: `Blackbelt` over a plain state object**, tested in `test/blackbelt.test.js`. A new domain operation, submitting a belt (`submitBelt(beltId, consultantId)`), carries all the business rules:
   - the success case, where the belt goes from `IN_PROGRESS` to `NEED_VALIDATION`;
   - rule 2, the caller is not the belt's consultant;
   - rule 3, every status other than in progress;
   - rule 4, no objective, tested with a hand-made state because the CLI can't reach it;
   - rule 1, remaining objectives listed by id and label;
   - the check order;
   - the state is unchanged on any refusal.

   Every other rule (request, assign, add, validate, decide) is already tested here.

2. **The CLI seam: the CLI run as a subprocess against a temporary state file**, tested in `test/cli.test.js`. These tests pin the contract from ADR-0003:
   - `submit B-3 linus` prints `B-3: NEED_VALIDATION` with exit code 0, and the change is still there on the next command;
   - `submit B-2 ada` prints `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop` on stderr, exits with code 2, and leaves the state unchanged;
   - `submit` appears in the usage text.

At the top of the pyramid, the ticket's Feature Path drives the real CLI with the four acceptance criteria from the story.

The alternative is a single seam, the CLI only, with rule 4 tested through a crafted state file. I'd rather keep both, because that's how the existing rules are tested and the domain tests are faster and more precise.

Do these seams match what you expect?

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: CLI seam only, rule 4 through a crafted state file -->
### You

Yes, both seams, as you propose.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(mkdir -p .scratch/belt-submission && cat > .scratch/bel…)

I wrote the spec to `.scratch/belt-submission/SPEC.md` with `Status: ready-for-agent`. It references BELT-US-1 and the integration branch, and it isn't committed yet.

It records what we settled in the grilling and the two test seams you just confirmed:

- **Command:** `submit <belt> <consultant>`, backed by a new domain operation `submitBelt`, with the five-step check order and the exact refusal messages.
- **Tests:** domain tests cover every rule, including rule 4 using a hand-made state. CLI tests cover the success output, the refusal for remaining objectives, and the usage text.
- **Feature Path:** the story's four acceptance criteria, run from the seed data, plus a sensei's `decide` on B-3 at the end.
- **Happy Path candidate:** the full belt journey from request to the sensei's decision. I'd propose it at the `integration → develop` merge request.

Next step is `/to-tickets`, which splits the spec into tickets, pushes the integration branch and adds a link back on the business story. Should I commit the spec on the integration branch first?

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Not yet, I want to read the spec first -->
### You

Yes, commit the spec on the integration branch.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git add .scratch/belt-submission/SPEC.md && git commit -q -F - <<'EO…)

I committed the spec on `integration/BELT-US-1-submit-my-belt-for-sensei-validation` as `15bb1df`, on top of the glossary commit. Nothing else is left to commit, and the branch is still local only.

Next step: `/to-tickets`, which splits the spec into tickets, pushes the branch and adds a link back on BELT-US-1.
