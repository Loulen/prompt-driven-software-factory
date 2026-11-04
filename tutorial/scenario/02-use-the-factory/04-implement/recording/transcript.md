---
step: 02-use-the-factory/04-implement
command: /implement
branch: integration/BELT-US-1-submit-my-belt-for-sensei-validation
commit: BELT-US-1 01: the belt's consultant submits a belt for a sensei's decision
session: new
via: feature/BELT-US-1-01-submit-belt
merge: Merge feature/BELT-US-1-01-submit-belt into integration (auto-merge: build + tests + FP green, no blocking finding)
branches:
removed:
recorded: 2026-11-03
recorder: Claude Code 2.1.317, claude-opus-5-5
pdsf: b6456d7
harness: claude
format: 1
---

# Recording — Implement one ticket (`/implement`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/implement .scratch/belt-submission/tickets/01-submit-a-belt-for-a-sensei-decision.md

<!-- pdsf-turn: agent -->
### Agent

I'll start by reading the ticket, spec, domain docs, and repo layout.

⏺ Bash(cat .scratch/belt-submission/tickets/01-submit-a-belt-for-a-sensei-decision.md && echo --…)
⏺ Bash(cat package.json src/blackbelt.js src/cli.js src/workflow.js src/store.js; cat docs/adr/0…)

Seams are already agreed in the spec (seam 1: `Blackbelt` domain; seam 2: CLI subprocess), so I'll proceed with those. Branching per git flow and reading the existing tests as prior art.

⏺ Bash(git checkout -b feature/BELT-US-1-01-submit-belt && git remote -v; cat test/blackbelt.tes…)

No remote configured, so merging will be local. **TDD — slice 1, seam 1 (domain): success case.** Red first:

⏺ Bash(cat >> test/blackbelt.test.js <<'EOF')
⏺ Edit(src/blackbelt.js)
⏺ Bash(node --test test/blackbelt.test.js 2>&1 | grep -E '^# (pass|fail)')

Green. **Slice 2: rule 2 — only the belt's consultant, checked before contents.** Red:

⏺ Bash(cat >> test/blackbelt.test.js <<'EOF')
⏺ Edit(src/blackbelt.js)
⏺ Bash(node --test test/blackbelt.test.js 2>&1 | grep -E '^# (pass|fail)')

**Slice 3: rule 3 — every status other than `IN_PROGRESS`.** Red:

⏺ Bash(cat >> test/blackbelt.test.js <<'EOF')
⏺ Edit(src/blackbelt.js)
⏺ Bash(node --test test/blackbelt.test.js 2>&1 | grep -E '^# (pass|fail)')

**Slices 4 & 5: rule 4 (no objective, hand-built state) and rule 1 (remaining objectives, one and several).** Red:

⏺ Bash(cat >> test/blackbelt.test.js <<'EOF')
⏺ Edit(src/blackbelt.js)
⏺ Bash(node --test test/blackbelt.test.js 2>&1 | grep -E '^# (pass|fail)')
⏺ Bash(cat >> test/blackbelt.test.js <<'EOF')

**Slice 6, seam 2 (CLI).** Red:

⏺ Bash(cat >> test/cli.test.js <<'EOF')
⏺ Bash(python3 - <<'EOF')
⏺ Bash(for f in src/*.js; do node --check $f || echo FAIL $f; done; echo build-ok; cat .gitignor…)
⏺ Agent(Independent code review)
⏺ Agent(Run Feature Path agentic test)

The independent review and the Feature Path run are both running in the background. I'll wait for their results before the green-gate decision.

The review found no blocking issues. I'll fold in one nit: the check-order test repeats a regex that the exact-message assertion already covers.

⏺ Bash(python3 - <<'EOF')
⏺ Bash(cat docs/agents/issue-tracker.md | sed -n '1,80p'; grep -n -i 'done\|closed\|status' docs…)
⏺ Bash(set -e)

Ticket 01 is done: the belt's consultant can now submit their in-progress belt with `submit <belt> <consultant>`. I committed it on `feature/BELT-US-1-01-submit-belt` and auto-merged it into `integration/BELT-US-1-submit-my-belt-for-sensei-validation`, as git flow allows for a ticket that passes build, tests and the Feature Path.

**What changed**
- **Domain:** `submitBelt(beltId, consultantId)` in `src/blackbelt.js` moves a belt whose objectives are all validated to `NEED_VALIDATION`. It refuses in the ticket's order: unknown belt, not the belt's consultant (the message names no objective), not in progress, no objective, objectives still to validate (listed by id and label). A refusal changes nothing.
- **CLI:** the `submit` command in `src/cli.js` prints `B-3: NEED_VALIDATION`. A refusal prints `refused: …` on stderr and exits with code 2. `submit` is listed in the usage text.
- **Tests:** 10 new domain tests and 3 new CLI tests, using the two test layers the spec set out (domain and CLI). Three of the domain tests passed as soon as they were written, because existing code already handled those cases: unknown belt, state unchanged after a refusal, and objectives frozen after submission. They lock that behaviour in rather than drive new code.

**Checks**
- **Build:** the project has no build step, so I used `node --check` on every source file. It passed.
- **Tests:** 43 of 43 pass, including after the merge.
- **Independent review:** a separate reviewer saw only the diff and the ticket and found no blocking issue. I fixed one of its three minor nits, a redundant check in a test. I kept the extra transition check in `submitBelt` so the workflow table stays the one place that defines allowed transitions.
- **Feature Path:** an agent drove the real CLI from the seed data, and all 5 steps passed. Linus's submission is accepted. Ada's own belt is refused, naming "Run a refactoring workshop". Ada submitting Linus's belt is refused. Linus's second submission is refused. Margaret then validates the belt.

**One non-blocking issue, outside this ticket:** a missing CLI argument comes back as a domain refusal, e.g. `submit` alone prints `refused: no belt undefined`. Every existing command already behaves this way. I noted it in the ticket's comments; it's worth its own ticket.

**Next steps**
- **Open the PR from the integration branch to `develop`:** this repo has no git remote, so I couldn't open a PR. The merge to `develop` is your decision. Before that PR, git flow calls for running the Happy Path suite (`/agentic-tests HP`) and pasting the result into it.
- **Add a Happy Path:** the spec suggests the full belt journey (request → mentor → objectives → submit → decision) as one. I can write it up with you then.
- **Delete the feature branch:** `feature/BELT-US-1-01-submit-belt` is merged and still exists locally. I can delete it if you'd like.
