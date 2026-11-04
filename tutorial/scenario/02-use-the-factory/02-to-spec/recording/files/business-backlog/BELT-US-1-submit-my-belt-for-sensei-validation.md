# Belt US-1 [user] Submit my belt for sensei validation

Status: In design

**INTENTION**

As a consultant, I want to submit my belt for the sensei's validation once my mentor has validated
all its objectives, **so that** my progress is recognised without waiting for someone to notice it.

**CONTEXT**

A consultant requests a belt, a mentor is assigned, sets the belt's objectives and validates them
one by one. Today the belt stays "in progress" forever: nothing lets the consultant say "I'm done,
please validate my belt". The sensei can already validate or refuse a belt that awaits validation,
but no belt ever gets there. There is no screen yet: the observable is the command line.

**EXPECTED BEHAVIOR**

- The consultant submits a belt in progress whose objectives are all validated → the belt now
  awaits the sensei's validation.
- The consultant submits a belt with objectives still to validate → the submission is refused, the
  refusal lists the remaining objectives (rule 1), and the belt is unchanged.

**BUSINESS RULES**

1. A belt can be submitted only when **every** objective is validated by the mentor; otherwise the
   submission is refused, listing the objectives that remain to validate.
2. Only the consultant who holds the belt submits it.
3. Only a belt in progress can be submitted (not a requested belt, nor one already awaiting
   validation, validated or refused).
4. A belt with no objective cannot be submitted.

**ACCEPTANCE CRITERIA**

- Linus submits his Cloud & DevOps WHITE belt, both objectives validated → the belt awaits the
  sensei's validation.
- Ada submits her Software Craftsmanship ORANGE belt, "Run a refactoring workshop" still to
  validate → refused, the message names "Run a refactoring workshop"; the belt stays in progress.
- Ada submits Linus's belt → refused (rule 2).
- Linus submits his belt a second time → refused (rule 3).

**OUT OF SCOPE**

- Notifying the sensei (email, chat) — later.
- Withdrawing a submission — not needed yet.
- The sensei's decision itself — already exists.

**DEPENDENCIES**

- None: requests, mentors, objectives and the sensei's decision already exist.
