# `/clean-context` is a third writer — it prunes, never decides

Without this ADR, a reviewer or an agent would reject `/clean-context`'s PRs citing the
single-writer rule (ADR-0004), and context cleanup would have to happen inside grilling
sessions — exactly where the bias it exists to counter is strongest: a decision's author, right
after investing in it, grades everything as "surprising" and "worth keeping".

The writers of `CONTEXT.md`, the ADRs, and code comments therefore split by verb:

- The two grilling sessions (ADR-0004) **add and amend** decisions.
- `/clean-context` **deletes and tightens**, under the named-counterfactual rule
  (`domain-modeling`'s `ADR-FORMAT.md`), on its own refactor branch, through a PR a human merges.
  It never adds a decision and never changes one's meaning; a text it finds *wrong* (not just
  noisy) is routed to a grilling session, untouched.

## Considered Options

- **Have `grill-with-docs` run the cleanup.** Rejected: cleanup is repo-wide and story-less, and
  grilling is the moment of maximal sunk-cost attachment to the freshly written text.
- **Keep a strict single writer and never prune.** Rejected: the write-time gate leaks (every
  fresh decision feels surprising to its author), and the accumulated noise is billed to every
  agent session that loads the context.
