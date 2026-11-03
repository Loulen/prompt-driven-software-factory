---
title: Scaffold the factory
kind: agent
command: /build-factory
---

## What you do

You type `/build-factory`. It sees an un-wired repo and proposes **scaffold** mode, then asks four
questions, one at a time, each with a short "why":

1. **Business backlog** — where do the user stories live? Here: **local markdown**, the
   `business-backlog/` folder (open it: `Belt US-1` is waiting there).
2. **Technical backlog** — where do the agents' tickets go? Here: **local markdown** under
   `.scratch/` (no remote).
3. **Triage labels** — keep the default role names (`ready-for-agent`, …).
4. **Domain docs** — single context.

## Under the hood

The skill writes the factory's **ports**, one file per decision, under `docs/agents/`:
`business-backlog.md`, `issue-tracker.md`, `triage-labels.md`, `domain.md`, plus the default user
story layout `us-format.md`. It adds the method constants and an `## Agent skills` block to the
agent file (`AGENTS.md`), and lays down an empty `CONTEXT.md` and `docs/adr/`.

Every other skill reads these ports instead of hard-coding a tool: `/to-spec` and `/to-tickets`
read `issue-tracker.md` to know whether to write a markdown file, call `gh issue create` or
`glab issue create`. **On a real project** you answer GitHub or GitLab for the technical backlog
(proposed from your `git remote`), and Jira, Notion, Linear… for the business one. Nothing else
changes downstream. The scaffold wires the *workflow*, never the *stack*: it never asks for your
framework or test command, agents discover those at runtime.
