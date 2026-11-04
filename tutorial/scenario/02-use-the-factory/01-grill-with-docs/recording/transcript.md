---
step: 02-use-the-factory/01-grill-with-docs
command: /grill-with-docs
branch: integration/BELT-US-1-submit-my-belt-for-sensei-validation
commit: BELT-US-1 grilling: sharpen Submission, Belt and Objective in the glossary
session: new
via:
merge:
branches:
removed:
recorded: 2026-11-03
recorder: Claude Code 2.1.284, claude-opus-5-5
pdsf: b6456d7
harness: claude
format: 1
---

# Recording — Grill the business story (`/grill-with-docs`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/grill-with-docs business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md

<!-- pdsf-turn: agent -->
### Agent

⏺ Skill(grilling)
⏺ Skill(domain-modeling)
⏺ Bash(cat business-backlog/BELT-US-1-*.md; echo ----; cat CONTEXT.md; ls d…)
⏺ Bash(cat docs/adr/*.md; for f in src/*.js; do echo "=== $f"; cat $f; done…)
⏺ Bash(git checkout -b integration/BELT-US-1-submit-my-belt-for-sensei-vali…)

I've created `integration/BELT-US-1-submit-my-belt-for-sensei-validation` from `develop`, and the docs from this session will be written there. I read the story against `CONTEXT.md`, the 3 ADRs and the code. Most of it already fits: the `IN_PROGRESS → NEED_VALIDATION` transition exists in `workflow.js`, objectives are already frozen outside `IN_PROGRESS`, and `decide` works with any sensei. What's missing is the submit command and its rules.

## Round 1

❓ **Q1 - Does a submission go to one named sensei?** The glossary says a submission "hands it to **a** sensei". The story says "awaits **the** sensei's validation". The code lets **any** sensei run `decide`. So either:
(a) the submission goes to every sensei, and any of them can decide, or
(b) the consultant (or the system) names one sensei when submitting.

➡️ (a). Nothing in the story asks for picking a sensei, notifying one is out of scope, and the code already works this way. I'd change the glossary entry to "hands it over for a sensei's decision" so it doesn't suggest one particular sensei.

❓ **Q2 - "Holds" means two different things.** Rule 2 says "the consultant who **holds** the belt". The glossary uses *holds* for a colour you have earned: "holds a colour once a belt of that colour is validated". With an in-progress belt, Linus doesn't *hold* anything yet.

➡️ Call it **the belt's consultant**, as the code does with `belt.consultantId`, and add "_Avoid_: holder, owner (of a belt)" to the **Belt** entry so *hold* only ever applies to colours.

❓ **Q3 - What does the command look like?** The existing commands put the person doing the action last: `validate-objective <belt> <objective> <mentor>` and `decide <belt> <sensei> …`.

➡️ `submit <belt> <consultant>`, for example `submit B-3 linus`. On success it prints `B-3: NEED_VALIDATION`, the same way `decide` prints `B-1: VALIDATED`.

❓ **Q4 - Rule 4 ("no objective") can't happen today.** A belt only enters `IN_PROGRESS` when its first objective is added, and objectives can't be removed. So any belt with zero objectives is `REQUESTED` or `MENTOR_ASSIGNED`, and rule 3 already refuses it.
(a) Keep rule 4 as a rule in the domain, checked explicitly with its own message ("belt B-x has no objective"), or
(b) treat it as covered by rule 3 and don't add a separate check or test.

➡️ (a), as one cheap explicit guard. The story states it as a business rule, and it would still hold if objectives ever became removable. I'll also record it in the glossary: "a belt in progress always has at least one objective."

❓ **Q5 - Which refusal wins when several rules fail?** Example: Ada submits Linus's belt while it's already `NEED_VALIDATION`.

➡️ Check in this order: belt exists → caller is the belt's consultant (rule 2) → status is `IN_PROGRESS` (rule 3) → has objectives (rule 4) → all objectives validated (rule 1). This way a non-owner learns nothing about someone else's objectives, and the list of remaining objectives only appears when it's the last thing blocking. The story's examples all come out as written in this order.

❓ **Q6 - How is the rule 1 refusal worded?** Per ADR-0003 it goes on stderr as a single `refused: <reason>`, and it has to name the remaining objectives.

➡️ One line with each remaining objective's id and label, separated by `; `:
`refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`
The id lets the mentor act on it directly with `validate-objective`.

❓ **Q7 - How is the rule 3 refusal worded?** The generic `#move` message would print `belt B-3 cannot go from NEED_VALIDATION to NEED_VALIDATION`, which is confusing.

➡️ A specific message in the style of `add-objective`'s: `refused: cannot submit a belt in NEED_VALIDATION`.

❓ **Q8 - Do we need an ADR?** I can't name a concrete mistake that a competent agent would make without one and that the tests or code wouldn't catch. Every decision above is either a glossary entry or part of the CLI contract, which the spec and tests will pin down.

➡️ No ADR. I'll update `CONTEXT.md` only (Submission, Belt, Objective).

Answer by number. "ok" accepts my recommendation.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: All ok, but write an ADR for the refusal order | 1 (b): the consultant names a sensei, the rest ok -->
### You

All ok: 1 (a), 2, 3, 4 (a), 5, 6, 7, and 8 no ADR.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(python3 - <<'EOF')

I've updated `CONTEXT.md` on `integration/BELT-US-1-submit-my-belt-for-sensei-validation`. It's not committed yet.

- **Belt:** adds the term **the belt's consultant**. Its *Avoid* line now covers "holder"/"owner", so *hold* only ever refers to a colour.
- **Submission:** the belt's consultant hands the belt over for a sensei's decision. They can only do this when the belt has objectives and all of them are validated. The submission names no particular sensei; any sensei can decide.
- **Objective:** a belt in progress always has at least one objective.

As agreed, there's no ADR. The CLI details are for the spec, not the glossary:
- **Command and output:** `submit <belt> <consultant>` prints `B-3: NEED_VALIDATION` on success.
- **Check order:** belt exists → caller is the belt's consultant → status is `IN_PROGRESS` → has objectives → all objectives validated.
- **Refusal messages:** a missing-objectives refusal is one line, `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`. A wrong-status refusal reads `refused: cannot submit a belt in NEED_VALIDATION`.

Nothing is left open. The rule that a sensei can't decide on a belt they mentored, or on their own, stays for a later story, as the glossary already says.

If that matches what you have in mind, the next step is **`/to-spec`**, which writes the spec for the technical backlog from this session. Should I commit the `CONTEXT.md` change on the integration branch first?

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Not yet, I want to reread CONTEXT.md -->
### You

Yes, commit it on the integration branch.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git add CONTEXT.md && git commit -q -F - <<'EOF')

I committed the `CONTEXT.md` change on `integration/BELT-US-1-submit-my-belt-for-sensei-validation` as `7b0a930`. The working tree is clean, and the branch is only local: `/to-tickets` pushes it later.

Next step: `/to-spec`, which writes the spec for the technical backlog from this session.
