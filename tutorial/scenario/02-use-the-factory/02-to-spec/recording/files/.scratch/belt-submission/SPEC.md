# Spec: submit a belt for a sensei's decision

Status: ready-for-agent

Business story: BELT-US-1 — `business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md`
Integration branch: `integration/BELT-US-1-submit-belt-for-validation`

## Problem Statement

A consultant's belt goes in progress when the mentor sets its first objective, and the mentor then validates the objectives one by one. Once every objective is validated, nothing lets the consultant say "I'm done". The belt stays in progress forever. The sensei can already decide on a belt awaiting validation, but no belt ever reaches that state, so a consultant's progress is never recognised unless someone happens to notice it.

## Solution

Add a new CLI command, `submit <belt> <consultant>`. The belt's consultant uses it to submit their in-progress belt once every objective is validated. The belt moves to awaiting validation (`NEED_VALIDATION`), where any sensei can decide on it with the existing `decide` command. If the submission breaks a rule, it is **refused** under the CLI contract (ADR-0003): the refusal names the reason, and for missing objectives it lists the objectives still to validate. The belt is left unchanged.

## User Stories

1. As a consultant, I want to submit my in-progress belt once all its objectives are validated, so that my progress is recognised without waiting for someone to notice it.
2. As a consultant, I want a successful submission to move my belt to awaiting validation, so that a sensei can take their decision on it.
3. As a consultant, I want the CLI to confirm a successful submission with the belt's new status, so that I know it worked.
4. As a consultant, I want a submission with objectives still to validate to be refused, so that a belt never reaches a sensei unfinished.
5. As a consultant, I want that refusal to list each remaining objective with its id and label, so that I know exactly what is left and can ask my mentor to validate it.
6. As a consultant whose belt has several objectives left, I want all of them listed in one refusal, so that I don't have to fix and retry them one at a time.
7. As a consultant, I want a refused submission to leave my belt exactly as it was, so that retrying later is safe.
8. As a consultant, I want my submission of someone else's belt to be refused, so that only the belt's consultant can declare it done.
9. As a consultant, I want a submission of someone else's belt to be refused before its objectives are inspected, so that a refusal never reveals another consultant's remaining objectives.
10. As a consultant, I want a second submission of a belt already awaiting validation to be refused, so that a submission can't be repeated or reset.
11. As a consultant, I want submitting a requested belt, or one with a mentor but no objective yet, to be refused, so that only a belt in progress can be submitted.
12. As a consultant, I want submitting a validated or refused belt to be refused, so that a closed belt stays final.
13. As a consultant, I want a belt with no objective to never be submittable, so that a belt can't be validated without the mentor setting a goal.
14. As a sensei, I want submitted belts to reach awaiting validation without being addressed to me personally, so that any sensei can take the decision.
15. As a sensei, I want to decide on a submitted belt with the existing `decide` command, so that the end-to-end lifecycle works.
16. As a mentor, I want a belt's objectives to be frozen once it is submitted, so that the sensei decides on the objectives the consultant submitted.
17. As a script author, I want `submit` to follow the CLI contract (stdout on success; `refused: <reason>` on stderr with exit code 2 on refusal), so that I can script against it like every other command.
18. As a CLI user, I want `submit` listed in the usage text, so that I can find the command.
19. As a CLI user, I want submitting an unknown belt or an unknown person to be refused, so that typos don't corrupt the state.

## Implementation Decisions

- **Domain**: add a `submitBelt(beltId, consultantId)` operation to the Blackbelt domain. It returns the belt. It uses the existing transition `IN_PROGRESS → NEED_VALIDATION`, which is already allowed by the workflow but not yet used. The workflow itself does not change.
- **Check order** (the first rule broken decides the refusal). Leave a code comment at the site:
  1. The belt exists.
  2. **Ownership (rule 2)**: the submitter is the belt's consultant. Otherwise refused. Checked first so that nothing about another consultant's belt leaks.
  3. **Status (rule 3)**: the belt is `IN_PROGRESS`. Otherwise refused, naming the current status. Checked before the objectives because a submitted belt's objectives are frozen, so listing them would mislead.
  4. **No objective (rule 4)**: refused if the belt has no objective. This guard is kept explicit in the domain, but **the CLI cannot reach it today**: a belt only becomes `IN_PROGRESS` when its first objective is added, so rule 3 catches belts without objectives first. No CLI message is promised for it.
  5. **Remaining objectives (rule 1)**: refused if any objective is still `TODO`.
- **Rule 1 refusal message** (CLI contract): `refused: belt <id> has objectives still to validate: <id>. <label>`. When several objectives remain, they are separated by `; ` (labels are free text and may contain commas). Example: `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`.
- **CLI**: new command `submit <belt> <consultant>`. It is not read-only, so the state is saved on success. Success prints `<belt>: NEED_VALIDATION` on stdout (the same shape as `decide`). Add a usage line: `submit <belt> <consultant>   The consultant submits their belt for a sensei's decision`. Refusals follow ADR-0003: stderr `refused: …`, exit code 2, state unchanged.
- **The submission does not name a sensei**: the belt waits in a shared queue, and any sensei may decide (the glossary already says so).
- **The status name stays `NEED_VALIDATION`**, which the glossary calls "awaiting validation". Renaming it would change the CLI contract and is not part of this spec.
- **No new data is recorded**: no submission date and no submitter field. The status change is enough.
- **The state schema does not change**: no new dependency (ADR-0001) and the same JSON state file (ADR-0002).

## Testing Decisions

- **What makes a good test**: only external behaviour (the domain operation's result or refusal, and the CLI's stdout/stderr/exit code/resulting state), never internals. A good test is one that would still pass after a refactor that keeps the behaviour.
- **Seam 1: the Blackbelt domain** (prior art: the existing domain tests built on an in-memory state with `belt(...)` overrides). This seam covers every rule:
  - Success: the belt becomes `NEED_VALIDATION`.
  - Rule 1: the refusal message lists every remaining objective, by id and label, separated by `; `.
  - Rule 2: someone else's belt is refused, including when it still has `TODO` objectives (the refusal must not list them).
  - Rule 3: each non-in-progress status is refused.
  - Rule 4: a belt with no objective is refused. Only reachable here, through a hand-built state.
  - A refused submission leaves the belt unchanged.
  - After a submission, objectives can no longer be added or validated (existing behaviour, asserted for this flow).
- **Seam 2: the CLI process** (prior art: the existing CLI tests that spawn the CLI against a temporary state file seeded from the seed data). This seam covers the contract on the seed:
  - `submit B-3 linus` prints `B-3: NEED_VALIDATION` with exit code 0, and `show B-3` then shows `NEED_VALIDATION`.
  - `submit B-2 ada` exits with code 2, stderr names `2. Run a refactoring workshop`, and B-2 stays `IN_PROGRESS`.
  - `submit B-3 ada` exits with code 2.
  - A second `submit B-3 linus` exits with code 2.
  - The usage text lists `submit`.
- **No new seam.**
- **Pyramid apex (agentic tests)**: the ticket's **Feature Path** drives the real CLI on a fresh state (`reset`) through the four acceptance criteria of BELT-US-1:
  - Linus submits B-3, which then awaits validation.
  - Ada submits B-2: refused, naming "Run a refactoring workshop", and B-2 stays in progress.
  - Ada submits B-3 (Linus's belt): refused.
  - Linus submits B-3 a second time: refused.

  It finishes with a sensei (margaret) deciding on B-3, to show the lifecycle now completes. That end-to-end journey (request → mentor → objectives → submit → decide) is a candidate for a **Happy Path**, to propose at the integration → develop MR (at most 3 HP; none exists yet).

## Out of Scope

- Notifying the sensei (email, chat).
- Withdrawing a submission (the lifecycle only moves forward).
- The sensei's decision itself (it already exists), and the rule that a sensei never decides a belt they mentored or their own (a later story).
- Renaming the `NEED_VALIDATION` status.
- Addressing a submission to a particular sensei.

## Further Notes

- Glossary updated during grilling (`CONTEXT.md`): **the belt's consultant** (a consultant *holds* colours, not belts) and **Submission** (handed over for *a* sensei's decision). Rule 2 of the business story reads "only the belt's consultant submits it".
- The seed already contains the acceptance data: B-3 (linus, cloud, WHITE, both objectives validated, mentor margaret) and B-2 (ada, craft, ORANGE, objective 2 "Run a refactoring workshop" still `TODO`).
