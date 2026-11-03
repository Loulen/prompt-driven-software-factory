---
title: Write the spec
kind: agent
command: /to-spec
---

## What you do

You type `/to-spec`. No new questions: it **synthesises** the grilling conversation into a spec and
publishes it on the technical backlog.

## Under the hood

The spec holds the problem, the solution, the user stories, the implementation and testing
decisions, and what is out of scope, in the vocabulary of `CONTEXT.md`. It keeps the business
reference (`Belt US-1`) for traceability.

Where it lands is decided by `docs/agents/issue-tracker.md`: here, a markdown file
`.scratch/<feature>/SPEC.md`. On GitHub it would be an issue created with `gh`, on GitLab with
`glab`, on Jira through its CLI or MCP server. Same skill, different port.
