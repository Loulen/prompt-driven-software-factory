---
step: 01-build-the-factory/02-scaffold
command: /build-factory
branch: develop
commit: Wire the agentic factory: ports, method constants, scaffold
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

# Recording — Scaffold the factory (`/build-factory`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/build-factory

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git remote -v; echo ---; ls -la; echo ---; ls docs docs/agents docs/…)
⏺ Bash(cat README.md business-backlog/README.md; ls -la .claude/skills | he…)

Here's what's in the repo now:

- **No git remote.** No GitHub or GitLab to connect to.
- **`CLAUDE.md` is a symlink to `AGENTS.md`.** Right now it only holds the installer's PDSF block. There's no `## Agent skills` section yet.
- **No `CONTEXT.md`, `docs/agents/` or `docs/adr/`.**
- **There is application code.** It's a Node CLI (`src/`, `test/`, `package.json`) for the Blackbelt domain: belts, mentors, objectives and a sensei. There's also a `business-backlog/` folder with one story, `BELT-US-1`.

So I see this as an **existing project**, and I'd start in **Scaffold** mode, then move on to Context mode. Correct me if you see it differently.

---

The method keeps two backlogs. The **business** one belongs to humans and holds the user stories. The **technical** one is used by agents and holds self-contained tickets. Design connects the two, and that's where most of the human effort goes. First we'll connect both backlogs to this repo, then we'll build the project context.

### A — Business backlog (project management)

This is where the **user stories** live, managed by the PO and the team. `/grill-with-docs` takes the story to design from here. At the end of the chain, `/to-tickets` adds links to the technical tickets it created back onto that story, so you can trace one to the other.

The repo already has one: **`business-backlog/`**, with one markdown file per story (`BELT-US-1-<slug>.md`). Each file has a `Status:` line (`Ready` / `In design` / `In review` / `Done`) and a `## Comments` section at the bottom where ticket links go. Since it's plain files, agents can read it and add the ticket links themselves.

**Where does your business backlog live?** I suggest keeping the **local markdown folder `business-backlog/`** as it is. You could also name another tool (Jira, Notion, Linear…) or mark it as "to define".

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Jira | Notion | To define later -->
### You

Keep the local markdown folder business-backlog/: one story per file, that's our business backlog.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(cd .claude/skills/build-factory; cat business-backlog.md; echo ======; c…)

Recorded: the business backlog is **local markdown in `business-backlog/`**, one story per file. Agents pick stories marked `Status: Ready`. The status moves to `In design` when design starts and to `In review` when the PR opens. Ticket links are added under `## Comments`. I'll write this up in `docs/agents/business-backlog.md` along with the other port docs once you've seen the draft.

---

### B — Technical backlog (tickets for agents)

This second backlog is written **by agents, for agents**:

- `/to-spec` writes the spec here.
- `/to-tickets` cuts it into **self-contained tickets**, each a vertical slice of the feature.
- `/triage` labels them.
- `git-flow` defines how they get merged.

These skills need to know which tool to use: `gh issue create`, `glab issue create`, or a markdown file.

The repo has **no git remote**, so the GitHub and GitLab CLIs have nothing to connect to. I suggest **local markdown under `.scratch/`**. It works like your business backlog: one directory per feature, each with a `SPEC.md` and a `tickets/NN-<slug>.md` file per ticket. Each ticket has a `Status:` line for its triage state and a `## Comments` section at the bottom.

Other options:
- **GitHub**: Issues via `gh`, once you add a GitHub remote.
- **GitLab**: Issues via `glab`, once you add a GitLab remote.
- **Other** (Jira, Linear…): describe your workflow in a paragraph and I'll write the port doc from it.

**Which tool for the technical backlog?**

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: GitHub Issues (gh) | GitLab Issues (glab) | Other (Jira, Linear…) -->
### You

Local markdown under .scratch/, as you suggest.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(cd .claude/skills/build-factory; cat triage-labels.md; echo =====; cat d…)

Recorded: the technical backlog is **local markdown under `.scratch/<feature-slug>/`**, with a `SPEC.md` and one `tickets/NN-<slug>.md` per ticket. Each ticket keeps its triage state on a `Status:` line and its history under `## Comments`.

---

### C — Triage vocabulary

`/triage` moves each technical ticket through five states, called roles. `/to-spec` and `/to-tickets` also set the `ready-for-agent` role, which means **"an agent can pick this up without any human context."** That's the role that lets agents work autonomously. Each role has to map to the exact string written in the ticket.

| Role | Meaning |
|---|---|
| `needs-triage` | a human must evaluate it |
| `needs-info` | waiting on the reporter |
| `ready-for-agent` | fully specified, an agent can take it alone |
| `ready-for-human` | needs a human to implement it |
| `wontfix` | will not be done |

The tracker is new, so there are no existing labels to match. Ticket statuses live in `.scratch/` and story statuses (`Ready` / `In design`…) live in `business-backlog/`, so the two sets of words won't get mixed up. I suggest **keeping the default names**, written as `Status: ready-for-agent` in each ticket.

**Do you want to rename any of these, or keep the defaults?**

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Map them to existing labels -->
### You

Keep the default names.

<!-- pdsf-turn: agent -->
### Agent

Recorded: the **five default role names**, written as `Status: <role>` in each ticket.

---

### D — Domain docs (layout)

The grilling sessions **write** two kinds of domain docs: `CONTEXT.md`, the glossary of domain terms, and the **ADRs** (architecture decision records), which record structural decisions. `/to-spec`, `/to-tickets`, `/tdd` and `/triage` **read** them so they use the project's vocabulary and follow its decisions. They need to know whether there's one context or several.

- **Single-context**: one `CONTEXT.md` and `docs/adr/` at the root. This fits most repos.
- **Multi-context**: a `CONTEXT-MAP.md` at the root pointing to one `CONTEXT.md` per context. This is typical of a monorepo.

Blackbelt is a single Node package with one domain: belts, disciplines, mentors, objectives and the sensei. It has a flat `src/`, so I suggest **single-context**.

**Single-context or multi-context?**

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Multi-context (CONTEXT-MAP.md) -->
### You

Single-context.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(cat .agents/skills/to-us/US-FORMAT.md; echo =====; sed -n 1,40p .age…)

All four decisions are made. Here's what I'll write. Nothing is on disk yet.

### Files

| File | Content |
|---|---|
| `AGENTS.md` (`CLAUDE.md` is a symlink to it) | The installer block, rewritten in place: the method rules (Agentic tests, Dev workflow, Git flow) plus a new `## Agent skills` section |
| `docs/agents/business-backlog.md` | Template, filled in for `business-backlog/` |
| `docs/agents/issue-tracker.md` | The local `.scratch/` template, copied as is |
| `docs/agents/triage-labels.md` | Template, default names, as `Status: <role>` |
| `docs/agents/domain.md` | Template, single-context |
| `docs/agents/us-format.md` | Exact copy of `to-us/US-FORMAT.md` (`BELT-US-1` already follows it) |
| `docs/adr/` | Empty, with a `.gitkeep` so git tracks it |
| `CONTEXT.md` | Minimal stub: `# Blackbelt`, a one-line description, an empty `## Language` |

### `business-backlog.md`: the filled-in part

```markdown
- Access / tool: local markdown files, read and edited directly (no CLI/MCP)
- Location: `business-backlog/`, one story per file: `<FEATURE>-US-<n>-<slug>.md` (e.g. BELT-US-1-…)
- Auth: none

Agent queue
- Where the agent picks: stories with `Status: Ready`
- Transition at start: `Ready` → `In design`
- Transition to review: `In design` → `In review` (then `Done` once merged, by a human)

Commands / gestures
# READ a story:        read business-backlog/<ref>-<slug>.md
# COMMENT on a story:   append under `## Comments` at the bottom (create the heading if missing)
# MOVE / change state:  edit the `Status:` line near the top
```

### `## Agent skills` block in `AGENTS.md`

```markdown
## Agent skills

### Business backlog
Local markdown, one story per file in `business-backlog/`; agents pick `Status: Ready`. See `docs/agents/business-backlog.md`.

### Technical backlog (issue tracker)
Local markdown under `.scratch/<feature-slug>/` (`SPEC.md` + `tickets/NN-<slug>.md`). See `docs/agents/issue-tracker.md`.

### Triage labels
The five default role names, as a `Status:` line in each ticket. See `docs/agents/triage-labels.md`.

### Domain docs
Single-context: `CONTEXT.md` + `docs/adr/` at the root. See `docs/agents/domain.md`.

### User-story layout
Default layout for business user stories. See `docs/agents/us-format.md`.
```

Two other points:
- **Git flow import:** I'll keep the installer's path, `@.agents/skills/git-flow/SKILL.md`. It's the same file as `.claude/skills/…`, because `.claude/skills` is a symlink to it.
- **PR reviewer:** git-flow still says `<reviewer to define>` for the PR reviewer. I won't change it in this pass. Tell me if you want a name filled in.

**Should I write it as shown, or do you want changes first?** After writing, I'll commit on `develop` (it's project setup, not a feature), unless you'd rather I didn't.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Change something first | Write it, but don't commit -->
### You

Write it as shown and commit on develop.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(mkdir -p docs/agents docs/adr; touch docs/adr/.gitkeep)

Now the agent file, replacing the installer block in place.

⏺ Bash(python3 - <<'PY')
⏺ Bash(git add AGENTS.md CONTEXT.md docs && git commit -q -F - <<'EOF')

The setup is written and committed on `develop` as `4e15062`.

**What's in place:**
- **`AGENTS.md`** (which `CLAUDE.md` points to): I rewrote the installer section to hold the method rules (Agentic tests, Dev workflow, Git flow) and the `## Agent skills` section.
- **`docs/agents/`**: the five setup files.
  - **Business backlog:** `business-backlog/`; agents pick stories marked `Status: Ready`.
  - **Technical backlog:** `.scratch/`.
  - **Triage labels:** the five default role names.
  - **Domain docs:** single-context.
  - **Story layout:** `us-format.md`, an exact copy of the default.
- **`CONTEXT.md`**: an empty glossary under a one-line description. **`docs/adr/`**: empty.

**Checks:** `.scratch/` is writable and isn't git-ignored, so tickets will be versioned. The business backlog is plain files with no login needed. The CLI runs (`node src/cli.js list`), so an agent can drive it for agentic tests. All 30 existing tests pass (`node --test`).

**Still open:**
- git-flow still says `<reviewer to define>` for the PR reviewer.
- There's no remote yet. When you add one, you can move the technical backlog to GitHub or GitLab by re-running `/build-factory`.

**Next:** run **`/build-factory`** again to start context mode. That session rebuilds the `CONTEXT.md` glossary and the founding ADRs (architecture decision records) from the code and your knowledge of the project. Since the project already has code, plan for about half a day. After that, `/verify-factory` gives a full health check. Then `BELT-US-1` (already `Ready`) can start the per-story chain: `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement`.
