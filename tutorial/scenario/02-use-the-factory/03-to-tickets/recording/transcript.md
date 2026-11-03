---
step: 02-use-the-factory/03-to-tickets
command: /to-tickets
branch: integration/BELT-US-1-submit-my-belt-for-sensei-validation
commit: BELT-US-1 tickets: 01 submit a belt; story moved to In design
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

# Recording — Slice the spec into tickets (`/to-tickets`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/to-tickets

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git remote -v; cat .agents/skills/agentic-tests/SCENARIO-FORMAT.md |…)

## Proposed breakdown

I recommend **a single ticket**. The feature is one command, one domain operation and five checks, so it fits easily in one context window, and no prefactoring is needed: the `IN_PROGRESS → NEED_VALIDATION` transition already exists.

I considered splitting it, for example "submit when everything is validated" first and "the refusals" second. But the first slice would merge into the integration branch a `submit` that anyone could run on any belt, even with objectives still open. That breaks the business rules on a shared branch, and the guards are too small to justify the risk.

**1. 01 — Submit a belt for a sensei's decision**
- **Blocked by:** none, it can start immediately.
- **What it delivers:** a new `submit <belt> <consultant>` command. When the belt's consultant submits an in-progress belt whose objectives are all validated, the belt moves to awaiting validation. Otherwise it's refused, following the agreed check order (belt exists, caller is the belt's consultant, belt in progress, has objectives, all validated). The missing-objectives refusal lists the remaining objectives by id and label, and a refusal never changes the state. Includes the usage text, the domain tests and the CLI tests from the spec.
- **Feature Path**, starting from the seed data:
  1. Linus submits his Cloud & DevOps WHITE belt, with both objectives validated → the belt awaits validation.
  2. Ada submits her Software Craftsmanship ORANGE belt → refused, and the message names "Run a refactoring workshop". The belt stays in progress.
  3. Ada submits Linus's belt → refused because she isn't the belt's consultant.
  4. Linus submits his belt a second time → refused because it's already awaiting validation.
  5. A sensei validates Linus's belt → the belt is validated, which completes the lifecycle.

The repo has **no git remote**, so I can't push the integration branch. I'll write the ticket and the comment on BELT-US-1 locally, and the push can happen once a remote exists.

Does one ticket work for you, or would you rather split it?

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Split it: the success path first, then the refusals -->
### You

One ticket is fine, publish it.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(mkdir -p .scratch/belt-submission/tickets && cat > .scratch/belt-sub…)
⏺ Bash(sed -i 's/^Status: Ready$/Status: In design/' business-backlog/BELT-…)

I wrote the ticket at `.scratch/belt-submission/tickets/01-submit-a-belt-for-a-sensei-decision.md` with `Status: ready-for-agent`. It isn't committed yet.

- **Ticket:** it says to branch from the integration branch and merge back into it, not `develop`. It contains the acceptance criteria (check order, messages, both test seams, ADRs 0001–0003) and the 5-step Feature Path.
- **BELT-US-1:** I added a `## Comments` section linking the spec and ticket 01. I also moved the story from `Ready` to `In design`, because the grilling is done and the technical counterpart now exists.
- **Not pushed:** the repo has no git remote, so the integration branch exists only locally. Once a remote is added, push it with `git push -u origin integration/BELT-US-1-submit-my-belt-for-sensei-validation`.

Should I commit the ticket and the story update on the integration branch? After that, the next step is `/implement` on ticket 01.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Not yet, I want to review the ticket -->
### You

Yes, commit them on the integration branch.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git add .scratch/belt-submission/tickets business-backlog/BELT-US-1-…)

I committed the ticket and the story update on `integration/BELT-US-1-submit-my-belt-for-sensei-validation` as `1886a23`. The branch now has the glossary (`7b0a930`), the spec (`15bb1df`) and this commit, and nothing is left uncommitted.

The branch is still local only, because the repo has no remote. It needs to be pushed once one is added.

Next step: `/implement` on `.scratch/belt-submission/tickets/01-submit-a-belt-for-a-sensei-decision.md`. It branches `feature/BELT-US-1-01-submit-belt` from the integration branch, writes the code test-first, runs an independent review and then the Feature Path. It merges into the integration branch only if the build, tests and Feature Path all pass with no blocking finding.
