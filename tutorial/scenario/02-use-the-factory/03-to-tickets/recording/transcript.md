---
step: 02-use-the-factory/03-to-tickets
command: /to-tickets
branch: integration/BELT-US-1-submit-belt-for-validation
commit: BELT-US-1 tickets: 01 submit a belt
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

# Recording — Slice the spec into tickets (`/to-tickets`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and
re-recording procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/to-tickets

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(mkdir -p .scratch/belt-submission/tickets; cat > .scratch/belt-submission/tickets/01-subm…)

I published one ticket, as I expected, and committed it as `f378844` on `integration/BELT-US-1-submit-belt-for-validation`. **The branch is not pushed**: the repo has no git remote. Everything is committed locally, so you can push once a remote exists.

**01 — The belt's consultant submits their belt for a sensei's decision** (`.scratch/belt-submission/tickets/01-submit-belt.md`, `ready-for-agent`)
- **Blocked by:** none.
- **What it delivers:** the `submit <belt> <consultant>` command. A successful submission moves the belt to `NEED_VALIDATION`. Rules 1–4 are refused in the agreed order, with the rule 1 message listing the remaining objectives, exit code 2, and the state left unchanged. `submit` is added to the usage text.
- **Feature Path:**
  1. Start from a fresh state.
  2. Linus submits B-3 → it awaits validation.
  3. Ada submits B-2 → refused, naming "Run a refactoring workshop".
  4. Ada submits B-3 → refused.
  5. Linus submits B-3 again → refused.
  6. Margaret validates B-3 → validated.
- **Branch:** `feature/01-submit-belt`, created from the integration branch and auto-merging back into it once build, tests and the FP are green.

**Why a single ticket:** it's one domain operation plus one CLI command. Splitting the domain from the CLI would make horizontal slices that can't be demoed on their own. The code needed no prefactoring: the `IN_PROGRESS → NEED_VALIDATION` transition already exists.

**Traceability:** I added a `## Comments` entry to BELT-US-1 pointing to the spec and the ticket.

Next step: `/implement` on ticket 01.
