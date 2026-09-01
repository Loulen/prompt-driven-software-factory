# ADR Format

ADRs live in `docs/adr/` and use sequential numbering: `0001-slug.md`, `0002-slug.md`, etc.

Create the `docs/adr/` directory lazily — only when the first ADR is needed.

## Template

```md
# {Short title of the decision}

{First sentence: the named counterfactual — "Without this, a competent agent would X." See
*When to offer an ADR* below.}
{1-3 sentences: what did we decide, and why.}
{If a measurement killed an alternative, the measurement.}
```

That's it. An ADR can be a single paragraph. The value is in recording *that* a decision was made and *why* — not in filling out sections.

## Optional sections

Only include these when they add genuine value. Most ADRs won't need them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) — useful when decisions are revisited
- **Considered Options** — only when the rejected alternatives are worth remembering
- **Consequences** — only when non-obvious downstream effects need to be called out

## What stays out

An ADR records the decision and its why. The implementation lives elsewhere — move to the ticket/PR (or delete):

- **Implementation plans**: step lists, exhaustive case matrices, test inventories, rollout steps. The grilling produced them; the ticket consumes them.
- **Code citations**: function names, `file.rs:42` references, pinned log strings, test names. They rot at the first refactor. Exception: a name that *is* the public contract (a CLI exit code, a wire-format field).
- **Restatements of what the code shows**: payload shapes, table schemas, UI copy.

What *does* belong even when it looks technical: the measurements that killed an alternative ("we tried X on the real data; it failed on the exact case it was meant to save"). No amount of code reading will ever reveal those — they are the treasure an ADR exists to keep.

**Size budget**: the decision, its counterfactual, and the measurements that killed the alternatives usually fit in ~30 lines. Past ~100, an ADR is almost certainly absorbing the implementation plan. Cut before committing.

## Amending an ADR

When a later decision revises an existing ADR:

- **Rewrite the body** in the current vocabulary so it reads true today. Never stack a dated addendum on top of a body that has become wrong, and never leave a translation instruction ("read X wherever it says Y").
- Mark the old ADR with a one-line pointer (`superseded by ADR-NNNN`, or `amended by ADR-NNNN: <one clause>`) in its status/preamble.
- Git owns the document's history; the document owns only the current truth. No dated correction trails.

## Numbering

Scan `docs/adr/` for the highest existing number and increment by one.

## When to offer an ADR: the named counterfactual

Before writing, produce this sentence:

> "Without this text, a competent agent would do X — and neither the compiler, the tests, nor a
> reading of the code would stop them."

1. **Name X.** A concrete, plausible action ("they would unpin the dependency below the CVE
   floor", "they would 'simplify' the live reference into a copy"). If no X can be named, there
   is nothing to record.
2. **Check that X gets through.** If X fails to compile, breaks a test, or is visible from a
   plain reading of the code, the repo defends itself — skip the ADR. Agents read code; anything
   derivable from it is noise billed to every future session that loads the context.
3. **The counterfactual is part of the text.** It is the ADR's first sentence. A text whose
   counterfactual can no longer be reconstructed gets deleted (the `clean-context` skill enforces
   this retroactively).

The older three-part test (hard to reverse / surprising / real trade-off) follows from this rule
but doesn't replace it: those three are qualities the author self-grades right after investing in
the decision, when everything feels surprising. The counterfactual is one falsifiable sentence
someone else can challenge — "no, X is caught by a test", "no, nobody would plausibly do X".

**Placement follows X's blast radius.** X committed at a single code site → a code comment at
that site, never an ADR (the constraint sits exactly where the next editor would undo it, with
zero drift). X committed across several sites or in a future design → an ADR. X committed by an
agent doing generic work far from the feature → one sentence in `CONTEXT.md` plus a pointer.

**Provenance is never content.** Mentally strip the issue numbers, the dates, the "we used to",
the "fixed by". If nothing remains that forbids or forces a future action, don't write it: git
owns history. A pointer (`#268`) attached to a surviving constraint is fine; a pointer that
carries the whole text is not.

### What qualifies

- **Architectural shape.** "We're using a monorepo." "The write model is event-sourced, the read model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate via domain events, not synchronous HTTP."
- **Technology choices that carry lock-in.** Database, message bus, auth provider, deployment target. Not every library — just the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; other contexts reference it by ID only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "We're using manual SQL instead of an ORM because X." Anything where a reasonable reader would assume the opposite. These stop the next engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We can't use AWS because of compliance requirements." "Response times must be under 200ms because of the partner API contract."
- **Rejected alternatives when the rejection is non-obvious.** If you considered GraphQL and picked REST for subtle reasons, record it — otherwise someone will suggest GraphQL again in six months.
