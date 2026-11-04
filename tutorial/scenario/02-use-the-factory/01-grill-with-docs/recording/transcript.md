---
step: 02-use-the-factory/01-grill-with-docs
command: /grill-with-docs BELT-US-1
branch: integration/BELT-US-1-submit-belt-for-validation
commit: BELT-US-1 grilling: belt's consultant, submission to any sensei
session: new
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

# Recording — Grill the business story (`/grill-with-docs BELT-US-1`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and
re-recording procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/grill-with-docs BELT-US-1

<!-- pdsf-turn: agent -->
### Agent

⏺ Skill(grilling)
⏺ Skill(domain-modeling)
⏺ Bash(ls; ls business-backlog; cat business-backlog/*US-1*; cat CONTEXT.md; ls docs/adr; cat do…)
⏺ Bash(cat docs/adr/*; find src test data -type f | head -50; cat package.json; wc -l $(find src…)
⏺ Bash(cat src/*.js data/seed.json)
⏺ Bash(git status -sb; git remote -v; git checkout -b integration/BELT-US-1-submit-belt-for-vali…)

I've read BELT-US-1, `CONTEXT.md`, the 3 ADRs and the code (`src/blackbelt.js`, `src/workflow.js`, `src/cli.js`, seed). I created the integration branch `integration/BELT-US-1-submit-belt-for-validation` from `develop`. There's no remote, so `develop` is as up to date as it can be.

**What the code shows:**
- The workflow already allows `IN_PROGRESS → NEED_VALIDATION`. No method uses it yet, so `submit` only needs to be wired up.
- A belt becomes `IN_PROGRESS` only when its first objective is added. So an in-progress belt always has at least one objective.
- The seed matches the acceptance criteria: B-3 is Linus's cloud WHITE belt with both objectives validated, and B-2 is Ada's craft ORANGE belt with objective 2 "Run a refactoring workshop" still to do.

## Round 1

❓ **Q1** - **Rule 4 can never fire on its own**: Belts with no objective are always `REQUESTED` or `MENTOR_ASSIGNED`, so rule 3 already refuses them. Should rule 4 have its own refusal (for example `refused: belt B-4 has no objective`), or does rule 3's message cover it (`belt B-4 is REQUESTED, only an IN_PROGRESS belt can be submitted`)?

➡️ Rule 3's message covers it. Keep rule 4 as a guard in the domain so the invariant is explicit, but don't promise a separate CLI message. The spec should say rule 4 can't be reached through the CLI today.

❓ **Q2** - **"Holds the belt" clashes with the glossary**: Rule 2 says "the consultant who **holds** the belt". In `CONTEXT.md`, a consultant *holds a colour* only once a belt of that colour is validated. An in-progress belt isn't "held" in that sense. Which phrasing should we use?
- (a) "the belt's consultant": the consultant the belt belongs to
- (b) redefine "holds" to cover both meanings

➡️ (a). Rule 2 becomes "Only the belt's consultant submits it", and "hold" stays reserved for colours. I'd also add "_Avoid_: holding a belt" to the Belt entry.

❓ **Q3** - **Does a submission name a specific sensei?** The glossary says a submission "hands it to **a** sensei". Today `decide` accepts any sensei. Should `submit` pick one (`submit B-3 linus margaret`), or does the belt go into a shared queue that any sensei can decide?

➡️ Shared queue: `submit <belt> <consultant>`, with no sensei named. Picking one would bring in assignment rules that the story doesn't ask for. I'd change the glossary to "hands it over for a sensei's decision".

❓ **Q4** - **Order of the checks**: When several rules are broken at once, which refusal wins? For example, Ada submits Linus's belt that still has objectives to do. Proposed order:
1. Ownership (rule 2)
2. Status (rule 3)
3. No objective (rule 4)
4. Remaining objectives (rule 1)

➡️ That order. Ownership comes first so a non-owner doesn't learn anything about someone else's belt. Status comes before objectives because a belt that's already submitted has frozen objectives, so listing them would mislead.

❓ **Q5** - **Format of the rule 1 refusal (part of the CLI contract, ADR-0003)**: The message has to name the remaining objectives. Should it include ids and labels or labels only, and how should multiple objectives be separated?

➡️ `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`, with multiple objectives separated by `; `. Labels are free text and can contain commas. The id helps the mentor run `validate-objective`.

❓ **Q6** - **Success output and status name**: The glossary says "awaiting validation" but the code and CLI say `NEED_VALIDATION`. Should we rename the status (a CLI contract change), or keep it? And what should success print?

➡️ Keep `NEED_VALIDATION`; renaming is a separate story. Success prints `B-3: NEED_VALIDATION`, the same shape as `decide`. Add a `submit <belt> <consultant>` line to USAGE.

❓ **Q7** - **Record anything on submission?** For example a `submittedAt` date or who submitted. Nothing in the story reads it.

➡️ No, the status change is enough. Adding unused fields is speculative.

Answer each one, or just say "agree" to the ones you accept.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: All ok, but submit names one sensei (Q3) | All ok, but rule 4 gets its own message (Q1) -->
### You

All ok, as you recommend.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(python3 - <<'EOF')

We agree on everything, so the grilling is done. I made two edits to `CONTEXT.md` on `integration/BELT-US-1-submit-belt-for-validation`. They aren't committed yet.

- **Belt**: a belt now belongs to one consultant, called **the belt's consultant**. I added "_Avoid_: 'holding' a belt", because consultants hold *colours*, not belts.
- **Submission**: only the belt's consultant can submit, and only once every objective is validated. The belt is handed over for *a* sensei's decision, not a named one, and any sensei can decide.

**No ADR.** None of these decisions needs one:
- **Check order** (ownership, then status, then no objective, then remaining objectives): this applies to one code site, so a code comment there is enough.
- **Refusal format and `B-3: NEED_VALIDATION` output**: these are one command's contract under ADR-0003, so they belong in the spec.
- **Keeping `NEED_VALIDATION`, the shared sensei queue, and storing no `submittedAt`**: these simply leave the code as it is, so there's nothing to guard against.

**Decisions for the spec:**
- **Command**: `submit <belt> <consultant>`, added to USAGE.
- **Success output**: prints `B-3: NEED_VALIDATION`.
- **Rule 1 refusal**: `refused: belt B-2 has objectives still to validate: 2. Run a refactoring workshop`, with multiple objectives separated by `; `. It exits with code 2 and leaves the state unchanged.
- **Rule 4**: stays as a guard in the domain. It can't be reached through the CLI today because rule 3 refuses those belts first.
- **Business rule wording**: rule 2 should read "Only the belt's consultant submits it" when it's carried into the spec.

**Next step:** run `/to-spec` to turn this into the spec on the technical backlog (`.scratch/<feature-slug>/SPEC.md`). If you want the glossary change on the branch first, I can commit it.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Not yet, I want to reread CONTEXT.md -->
### You

Yes, commit it, and stop there: I'll run /to-spec myself. In the next skills, go with your recommendations (test seams, ticket breakdown, commits) without asking me.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git add CONTEXT.md && git commit -q -m "BELT-US-1 grilling: belt's consultant, submission…)

The `CONTEXT.md` change is committed as `e7ddf3d` on `integration/BELT-US-1-submit-belt-for-validation`, and the working tree is clean. I'm stopping here; `/to-spec` is yours to run.

In the next skills I'll go with my own choices on test seams, ticket breakdown and commits without asking you. That stops at the git flow rules: sub-tickets can auto-merge into the integration branch after a green local check, but I won't merge anything into `develop` or `main` — that stays your call.
