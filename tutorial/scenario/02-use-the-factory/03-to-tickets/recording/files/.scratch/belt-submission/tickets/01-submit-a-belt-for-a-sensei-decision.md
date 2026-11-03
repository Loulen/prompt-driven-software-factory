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

- [ ] A new domain operation, submitting a belt (`submitBelt(beltId, consultantId)`), moves an in-progress belt whose objectives are all validated to `NEED_VALIDATION` and returns it.
- [ ] Refusals are domain errors checked in this order (the first failing check wins), and the state is unchanged after any of them:
  1. unknown belt → the existing `no belt <id>`;
  2. the caller is not the belt's consultant → `only the belt's consultant (<id>) can submit it` (rule 2). This reveals nothing about the belt's objectives;
  3. the belt is not in progress → `cannot submit a belt in <STATUS>` (rule 3), not the generic transition message;
  4. the belt has no objective → `belt <id> has no objective` (rule 4), an explicit guard even though it can't be reached today;
  5. objectives remain to validate → `belt <id> has objectives still to validate: <id>. <label>`, with several objectives separated by `; ` in objective order (rule 1).
- [ ] The CLI command `submit <belt> <consultant>` prints `<belt>: NEED_VALIDATION` and exits with code 0 on success, and the state is saved. A refusal prints `refused: <reason>` on stderr, exits with code 2 and leaves the state unchanged (ADR-0003).
- [ ] `submit` is listed in the usage text.
- [ ] After a submission, objectives can no longer be added or validated, and a sensei can decide on the belt.
- [ ] Domain tests (seam 1) cover the success case, each refusal (rule 4 with a hand-built state), several remaining objectives, the check order (a non-consultant gets the rule 2 refusal, which names no objective), and that the state is unchanged after a refusal.
- [ ] CLI tests (seam 2) cover `submit B-3 linus` (success, still visible on the next `show`), `submit B-2 ada` (the exact refusal message on stderr, exit code 2, belt still `IN_PROGRESS`), and the usage text.
- [ ] No new dependency (ADR-0001). State stays in the single JSON file (ADR-0002).

### Feature Path (FP)

Starting from the seed data (state reset):

1. Linus submits his Cloud & DevOps WHITE belt, with both objectives validated → the belt awaits validation.
2. Ada submits her Software Craftsmanship ORANGE belt → refused, and the reason names "Run a refactoring workshop". Her belt is still in progress.
3. Ada submits Linus's Cloud & DevOps WHITE belt → refused because she isn't the belt's consultant. Linus's belt is unchanged.
4. Linus submits his Cloud & DevOps WHITE belt a second time → refused because it already awaits validation.
5. A sensei (Margaret) validates Linus's belt → the belt is validated.

Verify: through the CLI (the primary surface). A belt's status is checked through `show` / `list`, and a refusal comes with exit code 2 and a reason on stderr. The state file may be probed only if the CLI is not enough.
