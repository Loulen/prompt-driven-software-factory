# 01 — Submit a belt for a sensei's decision

Business reference: BELT-US-1 (`business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md`)
Spec: `.scratch/belt-submission/SPEC.md`

**Branch:** implemented on the business-story integration branch
`integration/BELT-US-1-submit-my-belt-for-sensei-validation`. Branch
`feature/BELT-US-1-01-submit-belt` from it and merge back into it, **not** `develop`. The ticket
auto-merges into the integration branch after a green local check: build, tests and a green Feature
Path with no blocking finding.

**What to build:** the belt's consultant submits their in-progress belt from the CLI with
`submit <belt> <consultant>`. If the belt has objectives and all of them are validated, it moves to
awaiting validation (`NEED_VALIDATION`), and any sensei can then decide on it with the existing
`decide` command. Otherwise the submission is refused with a reason, and the belt is unchanged.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [x] A new domain operation, submitting a belt (`submitBelt(beltId, consultantId)`), moves an in-progress belt whose objectives are all validated to `NEED_VALIDATION` and returns it.
- [x] Refusals are domain errors checked in this order (the first failing check wins), and the state is unchanged after any of them:
  1. unknown belt → the existing `no belt <id>`;
  2. the caller is not the belt's consultant → `only the belt's consultant (<id>) can submit it` (rule 2). This reveals nothing about the belt's objectives;
  3. the belt is not in progress → `cannot submit a belt in <STATUS>` (rule 3), not the generic transition message;
  4. the belt has no objective → `belt <id> has no objective` (rule 4), an explicit guard even though it can't be reached today;
  5. objectives remain to validate → `belt <id> has objectives still to validate: <id>. <label>`, with several objectives separated by `; ` in objective order (rule 1).
- [x] The CLI command `submit <belt> <consultant>` prints `<belt>: NEED_VALIDATION` and exits with code 0 on success, and the state is saved. A refusal prints `refused: <reason>` on stderr, exits with code 2 and leaves the state unchanged (ADR-0003).
- [x] `submit` is listed in the usage text.
- [x] After a submission, objectives can no longer be added or validated, and a sensei can decide on the belt.
- [x] Domain tests (seam 1) cover the success case, each refusal (rule 4 with a hand-built state), several remaining objectives, the check order (a non-consultant gets the rule 2 refusal, which names no objective), and that the state is unchanged after a refusal.
- [x] CLI tests (seam 2) cover `submit B-3 linus` (success, still visible on the next `show`), `submit B-2 ada` (the exact refusal message on stderr, exit code 2, belt still `IN_PROGRESS`), and the usage text.
- [x] No new dependency (ADR-0001). State stays in the single JSON file (ADR-0002).

### Feature Path (FP)

Starting from the seed data (state reset):

1. Linus submits his Cloud & DevOps WHITE belt, with both objectives validated → the belt awaits validation.
2. Ada submits her Software Craftsmanship ORANGE belt → refused, and the reason names "Run a refactoring workshop". Her belt is still in progress.
3. Ada submits Linus's Cloud & DevOps WHITE belt → refused because she isn't the belt's consultant. Linus's belt is unchanged.
4. Linus submits his Cloud & DevOps WHITE belt a second time → refused because it already awaits validation.
5. A sensei (Margaret) validates Linus's belt → the belt is validated.

Verify: through the CLI (the primary surface). A belt's status is checked through `show` / `list`, and a refusal comes with exit code 2 and a reason on stderr. The state file may be probed only if the CLI is not enough.

## Comments

**2026-11-03 — `/implement`, green local check on `feature/BELT-US-1-01-submit-belt`:**
- Build: `node --check src/*.js` OK (no build step, ADR-0001). Tests: `npm test` 43/43 green.
- Independent `/code-review`: no blocking finding. Nits: one was folded in, and a redundant `#move` re-check was kept on purpose (the workflow table stays the single source of truth).
- FP via `/agentic-tests` against the real CLI: **green**, 5/5 steps. Extras also pass: objectives are frozen after submission, the state file is byte-identical after refusals, and usage lists `submit`.
- Non-blocking finding, pre-existing and out of scope: a missing CLI argument comes out as a domain refusal (`refused: no belt undefined`, exit 2). Every command does this. It deserves its own ticket.
