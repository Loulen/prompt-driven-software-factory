# 01 — The belt's consultant submits their belt for a sensei's decision

Spec: `.scratch/belt-submission/SPEC.md` — business story BELT-US-1.

**Branch:** implemented on the business-story integration branch
`integration/BELT-US-1-submit-belt-for-validation`. Branch `feature/01-submit-belt` from it and
merge back into it, **not** into `develop`. This ticket auto-merges into the integration branch once
the local check is green: build, tests, a green FP, and no blocking finding.

**What to build:** a new CLI command, `submit <belt> <consultant>`. The belt's consultant uses it to
declare their in-progress belt done once every objective is validated. The belt moves to awaiting
validation (`NEED_VALIDATION`), and any sensei can then decide on it with `decide`. A submission
that breaks a rule is refused under the CLI contract (ADR-0003) and leaves the state unchanged.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Submitting an in-progress belt whose objectives are all validated moves it to `NEED_VALIDATION`. stdout prints `<belt>: NEED_VALIDATION`, exit code 0, and the state is saved.
- [ ] Rule 1: if objectives remain `TODO`, the submission is refused as `refused: belt <id> has objectives still to validate: <id>. <label>`, with multiple objectives separated by `; `.
- [ ] Rule 2: only the belt's consultant can submit. Anyone else is refused, and the refusal never lists the belt's objectives.
- [ ] Rule 3: only an `IN_PROGRESS` belt can be submitted. A belt that is requested, has a mentor but no objective yet, is awaiting validation, is validated or is refused is refused, and the refusal names its status.
- [ ] Rule 4: a belt with no objective is refused. This is a domain guard; the CLI cannot reach it today because rule 3 catches those belts first.
- [ ] Check order: belt exists → ownership → status → no objective → remaining objectives. Leave a code comment at the site explaining why.
- [ ] Every refusal goes to stderr as `refused: …`, exits with code 2, and leaves the belt unchanged. An unknown belt or person is refused.
- [ ] Once a belt is submitted, its objectives can no longer be added or validated.
- [ ] The usage text lists `submit <belt> <consultant>`.
- [ ] Tests at the two existing seams: the Blackbelt domain tests (every rule, including rule 4) and the CLI process tests (the contract on the seed). No new dependency (ADR-0001), no schema change (ADR-0002).

### Feature Path (FP)

1. Start from a fresh state (seed restored).
2. Linus submits his Cloud & DevOps WHITE belt (B-3), both objectives validated → the belt now awaits the sensei's validation.
3. Ada submits her Software Craftsmanship ORANGE belt (B-2) → refused. The message names "Run a refactoring workshop", and B-2 is still in progress.
4. Ada submits Linus's belt (B-3) → refused.
5. Linus submits B-3 a second time → refused, and it still awaits validation.
6. Margaret (sensei) validates B-3 → the belt is validated, so the lifecycle now completes.

Verify: through the CLI (stdout/stderr, exit codes, `show`/`list`). Inspect the state file only if the CLI isn't enough.
