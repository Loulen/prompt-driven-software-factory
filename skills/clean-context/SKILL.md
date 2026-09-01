---
name: clean-context
description: Prune the project's accumulated context — CONTEXT.md, the ADRs, and code comments — deleting every text whose named counterfactual cannot be reconstructed. A heavy, occasional refactor on its own branch and PR. Use on "clean the context", "prune the docs/ADRs/comments", or when the domain docs have visibly bloated.
disable-model-invocation: true
---

# Clean Context

An occasional, repo-wide refactor that prunes the context the factory accumulates: `CONTEXT.md`,
`docs/adr/`, and code comments. It exists because the write-time gate leaks — every fresh decision
feels surprising to its author — so noise piles up and is billed to every future agent session
that loads it.

This skill is the **third sanctioned writer** of the domain docs (ADR-0005): the grilling sessions
*add and amend* decisions; `/clean-context` *deletes and tightens*. It never adds a decision and
never changes one's meaning.

## The rule: the named counterfactual

A text earns its place only if this sentence can be written about it:

> "Without this text, a competent agent would do X — and neither the compiler, the tests, nor a
> reading of the code would stop them."

- **No nameable X** (a concrete, plausible action) → delete.
- **X is caught** by the compiler, a test, or a plain reading of the code → delete; the repo
  defends itself. Agents read code — anything derivable from it is noise.
- **X survives** → keep, and make sure the text *states its counterfactual explicitly* (an ADR's
  first sentence; the body of a comment: `// Don't X: Y breaks`).

The write-time version of this gate lives in the `domain-modeling` skill's `ADR-FORMAT.md`; this
skill applies it retroactively to the stock.

### Why this converges (idempotence)

A raw "is this worth keeping?" judgment varies run to run; three runs would nibble three times.
The convergence mechanism is the third bullet above:

- **First pass — judge and embed.** Delete what has no reconstructible counterfactual; rewrite
  every survivor so its counterfactual is explicit in the text itself.
- **Later passes — verify, don't re-judge.** A text that already states its counterfactual is
  only checked: is X still plausible? still uncaught by code, tests, or compiler? If yes, leave
  it byte-identical. Re-litigating a stated counterfactual from scratch is the failure mode.

A clean run over an already-clean repo must produce an **empty diff**.

### Deletion bias is asymmetric

- **Aggressive** on: restated spec (payload shapes, UI behaviour, case matrices the code shows),
  provenance (issue numbers, dates, "we used to", "fixed by", "validated on"), changelog trails
  and stacked "amended by" addenda, content duplicated between `CONTEXT.md` and an ADR (the
  glossary keeps the term plus a pointer).
- **Protective** of: **measurements** — "we tried X on the real data; it failed exactly where it
  was meant to help". A measurement is the one thing no code reading ever reconstructs; git keeps
  deleted text but nobody will know to dig for it. When unsure whether a sentence is a
  measurement, keep it.
- **Pointers**: an issue number attached to a surviving constraint may stay; a pointer that
  carries the whole text may not (`git blame` does that better).

## Procedure

Follow the project git flow (`git-flow` skill) throughout — this is a refactor like any other.

0. **Position check.** Clean tree, up-to-date integration branch. Branch
   `refactor/clean-context-<yyyymmdd>` from it.
1. **ADRs**, one by one. Three outcomes: delete (no counterfactual survives), shrink (keep the
   decision + counterfactual + measurement, move or drop the absorbed implementation), or fold
   (rewrite a body buried under "amended by" trails so it reads true today, one status line
   pointing at the superseding ADR). An ADR found *wrong* — not noisy, wrong — is out of scope:
   open an issue routing it to a grilling session, and leave it.
2. **`CONTEXT.md`**, sentence by sentence, same rule. Inlined contracts collapse to term +
   pointer per `CONTEXT-FORMAT.md`.
3. **Code comments**, module by module, one commit per module. This is the bulk of the diff and
   it is assumed. The gate for a comment is the same sentence with X local: would the next
   competent editor wrongly "fix" or simplify this site? Surviving comments state the constraint
   (`// Don't X: Y breaks`), not the story. Comment-only discipline: the diff must touch no
   executable code — verify with the project build + tests before opening the PR.
4. **PR with a deletion ledger.** One PR toward the integration branch, listing every deleted or
   shrunk text with a one-line reason ("restates spec", "provenance only", "X is caught by test
   Y"). A human reviews and merges — this skill never merges, and never writes outside its
   branch.

## What this skill never does

- Add a decision, a term, or a comment that says something new.
- Change what a decision means (folding trails rewrites *form*, not meaning).
- Resolve a contradiction between a doc and reality — that's a grilling's job; route it.
- Touch executable code.
