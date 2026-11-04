# Business backlog

The **business** backlog carries the project's **user stories**. It is managed by humans
(PO / team); agents **read** it to start a design session and **post back** a traceability link
once the technical issues are created. It is the upstream source of the pipeline ("Understand
the need").

> Distinct from the **technical backlog** (`docs/agents/issue-tracker.md`), which is by and for
> agents. N business issues ≠ N technical issues: one story can yield several technical issues,
> or several stories can collapse into one.

## Tool

Tool: **local markdown** — one story per file in `business-backlog/` (see
`business-backlog/README.md`). Agents read and edit the files directly; no CLI/MCP needed.

- **Access / tool**: local markdown files, read and edited directly
- **Location**: `business-backlog/`, one story per file, named `<FEATURE>-US-<n>-<slug>.md`
  (e.g. `BELT-US-1-submit-my-belt-for-sensei-validation.md`)
- **Auth**: none
- **Layout of a story**: `docs/agents/us-format.md`

## Agent queue (story selection)

The agent does **not** pick at random: a human **selects** the stories to work on upstream by
setting their `Status:` line to `Ready`. The agent only picks from there.

- **Where the agent picks**: stories with `Status: Ready`
- **Transition at start**: `Ready` → `In design`
  (trigger when: grilling done + story selected + technical counterpart created)
- **Transition to review**: `In design` → `In review` (when the PR opens)
- **Done**: `In review` → `Done` — set by a human once merged

## Commands / gestures

```
# READ a story:        read business-backlog/<ref>-<slug>.md
# COMMENT on a story:   append under the `## Comments` heading at the bottom of the file
#                       (create the heading if missing)   (used by /to-tickets for traceability)
# MOVE / change state:  edit the `Status:` line near the top of the file
```

## Link to the technical backlog

Keep the **business reference** (story id, e.g. `BELT-US-1`, and its file path) in the spec /
technical tickets, for two-way traceability.

    business backlog (story selected by a human)
      └─ /grill-with-docs    → CONTEXT.md + ADRs   (on integration/<business-ref>-<slug>)
          └─ /to-spec        → spec on the technical backlog
              └─ /to-tickets → technical tickets + back-comment on the business story
                  └─ implementation (see git-flow)
