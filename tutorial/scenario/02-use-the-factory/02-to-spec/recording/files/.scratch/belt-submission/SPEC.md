# Spec: Submit a belt for a sensei's decision

Status: ready-for-agent

Business reference: BELT-US-1 — `business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md`
Integration branch: `integration/BELT-US-1-submit-my-belt-for-sensei-validation`

## Problem Statement

A consultant works through a belt: a mentor is assigned, sets the belt's objectives and validates
them one by one. Once every objective is validated, nothing lets the belt's consultant say "I'm
done". The belt stays in progress forever. A sensei can already decide on a belt awaiting
validation, but no belt ever reaches that state. The consultant's progress goes unrecognised
unless someone happens to notice it.

## Solution

The belt's consultant can **submit** their in-progress belt from the command line. If the belt has
objectives and all of them are validated, the belt moves to awaiting validation, and any sensei can
then take the decision with the existing `decide` command. Otherwise the submission is refused with
a reason. When objectives remain, the reason lists them by id and label, so the consultant and
their mentor know exactly what is left. A refused submission never changes the belt.

## User Stories

1. As a consultant, I want to submit my in-progress belt once all its objectives are validated, so that my progress is recognised without waiting for someone to notice it.
2. As a consultant, I want my submitted belt to move to awaiting validation, so that a sensei can take the decision.
3. As a consultant, I want a clear confirmation showing the belt and its new status, so that I know the submission worked.
4. As a consultant, I want my submission refused while objectives remain to validate, so that I don't hand over an unfinished belt.
5. As a consultant, I want the refusal to list each remaining objective by id and label, so that my mentor and I know exactly what is left.
6. As a mentor, I want the remaining objectives identified by their id, so that I can validate them directly with `validate-objective`.
7. As a consultant, I want my belt left unchanged when a submission is refused, so that I can keep working on it.
8. As a consultant, I want nobody but me to submit my belt, so that the decision to declare it done stays mine.
9. As a consultant, I want a refusal that tells me I'm not the belt's consultant when I try to submit someone else's belt, so that I understand why it failed.
10. As a consultant, I don't want to learn anything about another consultant's objectives by trying to submit their belt, so that the belt's details stay with the people concerned.
11. As a consultant, I want a second submission of the same belt refused, so that a belt awaiting validation can't be handed over twice.
12. As a consultant, I want a requested belt, or a belt with a mentor assigned but no objective yet, refused on submission, so that only a belt actually being worked on can be submitted.
13. As a consultant, I want a validated or refused belt refused on submission, so that a closed belt stays final (forward-only lifecycle).
14. As a consultant, I want the refusal to name the belt's current status when the status is wrong, so that I see where the belt stands.
15. As a consultant, I want a belt without any objective refused on submission, so that a belt is never validated without tailored objectives.
16. As a sensei, I want every submitted belt available to every sensei, so that any sensei can take the decision (no particular sensei is named).
17. As a sensei, I want to decide on a submitted belt with the existing `decide` command, so that the end-to-end lifecycle finally works.
18. As a mentor, I want a submitted belt's objectives frozen, so that the belt the sensei decides on is the belt the consultant submitted.
19. As a script author, I want `submit` to follow the CLI contract (exit code 0 on success, a `refused: <reason>` message on stderr with exit code 2 on a refusal, the state unchanged), so that I can script against it like every other command.
20. As a CLI user, I want `submit` listed in the usage text, so that I can discover it.
21. As a CLI user, I want the submission saved, so that the next command (`show`, `list`, `decide`) sees the belt awaiting validation.
22. As a consultant, I want a submission of an unknown belt refused, so that a typo doesn't go unnoticed.

## Implementation Decisions

- **Domain operation.** A new operation on the `Blackbelt` domain, `submitBelt(beltId, consultantId)`, moves a belt from `IN_PROGRESS` to `NEED_VALIDATION` (a transition the belt workflow already allows) and returns the belt. Every refusal is a `DomainError`, and the domain state is left untouched.
- **Check order** (the first failing check wins):
  1. The belt exists. Refused with the existing "no belt <id>" message.
  2. The caller is the belt's consultant (rule 2). Refused with a reason naming the belt's consultant, in the style of the mentor check, e.g. `only the belt's consultant (linus) can submit it`. This is checked before anything about the belt's contents, so someone else learns nothing about its objectives.
  3. The belt is in progress (rule 3). Refused with `cannot submit a belt in <STATUS>`, not with the generic transition message.
  4. The belt has at least one objective (rule 4). Refused with `belt <id> has no objective`. An in-progress belt always has an objective today, but the business rule gets its own explicit guard.
  5. Every objective is validated (rule 1). Refused with `belt <id> has objectives still to validate: <id>. <label>`, with several remaining objectives separated by `; ` in objective order. Example: `belt B-2 has objectives still to validate: 2. Run a refactoring workshop`.
- **CLI command.** `submit <belt> <consultant>`. The person acting comes last, as in `validate-objective` and `decide`. On success it prints `<belt>: <STATUS>` (e.g. `B-3: NEED_VALIDATION`), the same way `decide` does. It is a writing command, so the state is saved on success. A refusal follows ADR-0003: `refused: <reason>` on stderr, exit code 2, state unchanged. Add the command to the usage text.
- **No sensei is named on submission.** The belt carries no "assigned sensei" field, and any sensei may decide (the existing `decide` behaviour).
- **No schema change.** The belt keeps its existing shape. Only its status changes.
- **Respect ADR-0001** (Node built-ins only, no new dependency) and **ADR-0002** (one local JSON state file, rewritten whole on each command).
- **Vocabulary** follows `CONTEXT.md`: *submission*, *the belt's consultant* (never "holder"/"owner"), *awaiting validation*, *decision*.

## Testing Decisions

- **What makes a good test here:** it exercises external behaviour only: what the domain operation returns or refuses, and what the CLI prints, its exit code and the saved state. It never tests private helpers or the internal order of calls.
- **Seam 1, the domain** (`Blackbelt` over a plain state object; prior art: the existing domain tests for `requestBelt`, `addObjective`, `validateObjective` and `decideBelt`). Cover:
  - a fully validated in-progress belt goes to `NEED_VALIDATION`;
  - rule 2: someone other than the belt's consultant is refused;
  - rule 3: every status other than `IN_PROGRESS` is refused;
  - rule 4: a hand-built state with an in-progress belt without objectives is refused;
  - rule 1: the remaining objectives are listed by id and label, including the case of several;
  - the check order: a non-consultant submitting a belt with remaining objectives gets the rule 2 refusal and sees no objective;
  - an unknown belt is refused;
  - a refusal leaves the state unchanged;
  - after a submission, objectives can no longer be added or validated, and a sensei can decide.
- **Seam 2, the CLI** (the CLI run as a subprocess against a temporary state file; prior art: the existing CLI tests). Cover:
  - `submit B-3 linus` prints `B-3: NEED_VALIDATION`, exits with code 0, and a following `show` sees the new status;
  - `submit B-2 ada` prints `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop` on stderr, exits with code 2, and the belt is still `IN_PROGRESS`;
  - the usage text lists `submit`.
- **Apex, agentic tests.** The ticket's **Feature Path** drives the real CLI from a shell, starting from the seed (`reset`), through the story's acceptance criteria:
  1. Linus submits B-3 (Cloud & DevOps WHITE, both objectives validated). The belt awaits validation.
  2. Ada submits B-2 (Software Craftsmanship ORANGE). Refused: the message names "Run a refactoring workshop" and B-2 stays in progress.
  3. Ada submits B-3, Linus's belt. Refused (rule 2).
  4. Linus submits B-3 again. Refused (rule 3).

  As an extra check, a sensei then decides on B-3 with `decide`, completing the lifecycle. The Feature Path is the ticket's auto-merge gate.
- **Happy Path candidate.** The full belt journey (request → assign a mentor → add and validate objectives → **submit** → the sensei's decision) is the product's core value and only becomes possible with this feature. It is a strong candidate for one of the at-most-3 Happy Paths, to propose at the `integration → develop` merge request.

## Out of Scope

- Notifying a sensei (email, chat).
- Withdrawing a submission or reopening a belt (the lifecycle is forward-only).
- The sensei's decision itself (it already exists).
- Assigning or choosing a particular sensei.
- The rule that a sensei never decides a belt they mentored, nor their own (a later story).
- Any UI beyond the CLI.

## Further Notes

- The glossary was sharpened during the grilling (`CONTEXT.md`: Belt, Submission, Objective). No ADR was needed: every decision is either a glossary entry or part of the CLI contract, which the tests pin down.
- Seed data covers the acceptance criteria as is: B-2 (ada, craft, ORANGE, one remaining objective) and B-3 (linus, cloud, WHITE, all objectives validated).
