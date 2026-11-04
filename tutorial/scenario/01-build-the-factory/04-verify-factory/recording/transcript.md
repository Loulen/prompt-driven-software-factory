---
step: 01-build-the-factory/04-verify-factory
command: /verify-factory
branch: develop
commit: /verify-factory: Check the factory's health
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

# Recording — Check the factory's health (`/verify-factory`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/maintainers/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/verify-factory

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(ls -la; ls docs docs/agents docs/adr; grep -n -i "method constant\|#…)
⏺ Bash(cat .gitignore; echo ---; cat package.json; ls src test data busines…)
⏺ Bash(rmdir .scratch && echo removed-probe-dir; sed -n 150,175p .agents/sk…)

# /verify-factory: Blackbelt (lite)

Everything the factory needs is wired. No check failed, so there is nothing to fix.

| # | Check | Result | Evidence |
|---|---|---|---|
| 1 | Scaffold present | ✅ pass | `CLAUDE.md` links to `AGENTS.md`. It has the method constants (`## Agentic tests (concept)`, `## Dev workflow`) and `## Agent skills`. All 4 port files in `docs/agents/` exist, plus `docs/adr/` and `CONTEXT.md`. |
| 2 | Factory files are committed, not ignored | ✅ pass | `git check-ignore` on `.agents/skills`, `.claude/skills`, `CONTEXT.md`, `docs`, `docs/adr` and `docs/agents` flags nothing. `.gitignore` only excludes `.blackbelt-state.json` (local CLI state) and `node_modules/`, which is correct. |
| 3 | Context filled | ✅ pass | `CONTEXT.md` has a real glossary: Discipline, Colour, Belt, Belt lifecycle, Submission, Decision, Objective, Consultant, Mentor, Sensei, each with *Avoid* terms. There are 3 foundational ADRs: no dependencies, local JSON state, CLI as the primary surface. |
| 4 | Technical backlog (list and create) | ✅ pass | It's local markdown under `.scratch/`. That folder doesn't exist yet (normal before the first `/to-spec`), and the repo root is writable. |
| 5 | Business backlog reachable | ✅ pass | It's local markdown in `business-backlog/` with no login needed. There is 1 story, `BELT-US-1`, marked `Status: Ready`. |
| 6 | Triage labels | ➖ n/a | The backlog is local, so labels are `Status:` lines in the files. All five roles are listed in `triage-labels.md`. |
| 7 | Tool logins | ➖ n/a | The ports don't name any CLI that needs a login. `gh` and `glab` are installed but not used. |
| 8 | Agentic test driver | ✅ pass | The primary surface is the command line (ADR-0003), so the driver is **tmux**. tmux 3.4 is installed, and a test session opened and ran `node src/cli.js`, which printed its usage text. Node is v22. |
| 9 | Git-flow health | ✅ pass for `develop`, ➖ n/a for protection | `develop` exists (`84c2449`) and so does `main`. The repo has **no remote**, so there's no `main` branch protection to check. Turn it on when you add GitHub or GitLab. |
| 10 | User story template | ✅ default (untailored) | `docs/agents/us-format.md` is byte-identical to the core template. The one story on file, `BELT-US-1`, follows it exactly (all 7 sections), so the template doesn't need changing. |

**For later, not a fail:** `docs/test-scenarios/` doesn't exist yet, so there are no Happy Path tests. They're only needed before the first `integration → develop` PR.

**Mistake I fixed:** during check 4 I created an empty `.scratch/` folder, which this check isn't supposed to do. I deleted it straight away, so the working tree is as I found it.

## Next step

`BELT-US-1` is marked `Ready`, so you can start its design session:

```
/grill-with-docs business-backlog/BELT-US-1-submit-my-belt-for-sensei-validation.md
```

That creates `integration/BELT-US-1-submit-my-belt-for-sensei-validation` from `develop` and runs the design grilling. After that come `/to-spec` and `/to-tickets`.
