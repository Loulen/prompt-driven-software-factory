---
step: 01-build-the-factory/03-context
command: /build-factory
branch: develop
commit: Bootstrap project context: glossary + foundational ADRs
session: new
via:
merge:
branches:
removed: docs/adr/.gitkeep
recorded: 2026-11-03
recorder: Claude Code 2.1.284, claude-opus-5-5
pdsf: b6456d7
harness: claude
format: 1
---

# Recording — Bootstrap the project context (`/build-factory`)

A real run of the PDSF skill on a fresh blackbelt-lite tutorial workspace, recorded with
`tutorial/record/record.sh`. The files it produced are in `files/`. Format and re-recording
procedure: `tutorial/README.md` § Recordings.

<!-- pdsf-turn: learner -->
### You

/build-factory

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git remote -v; ls -la; ls docs docs/agents docs/adr 2>&1; echo ---; cat CONTEXT.md 2>&1; …)
⏺ Bash(cat README.md package.json; for f in src/*.js; do echo "=== $f"; cat $f; done; cat data/s…)
⏺ Bash(ls .claude/skills/domain-modeling .claude/skills/grilling; cat .claude/skills/domain-mode…)

Context mode it is. Here's what I found in the repo:

| Check | Finding |
|---|---|
| Ports | All five `docs/agents/*.md` are wired: local business backlog, local `.scratch/` tracker, default triage labels, single-context domain, default US layout. `AGENTS.md` has the `## Agent skills` block, and `CLAUDE.md` is a symlink to it. |
| `CONTEXT.md` | Still a stub: a title, a one-line vision and an empty `## Language`. |
| `docs/adr/` | Empty. |
| Code | Yes. It's an existing project (Blackbelt lite: a Node CLI with no dependencies, plus a domain model and tests). |
| Branch | `develop`, clean, which is where this output belongs. |

**Mode: Context, existing project.** We'll rebuild the glossary and the foundational ADRs by comparing the business vision against the code. These usually take about half a day. This codebase is small (5 source files and one story), so expect it to take much less.

I've read all of `src/`, the seed data, the README and story BELT-US-1. The facts come from there. What I need from you are the **decisions**: where the code is ambiguous, or where it might be accidental rather than intended. I'll write each answer into `CONTEXT.md` or an ADR as soon as it's settled.

---

### Round 1: the core language

❓ **Q1 - What is a "Belt"?** The code uses "belt" for two different things:
- **the rank**: "Ada holds the ORANGE belt in Craft"
- **the attempt**: a `B-n` record with a mentor, objectives and a status. A refused attempt followed by a new request creates a *second* belt of the same colour.

Should the glossary keep **Belt** for the attempt and use a separate word for the rank (e.g. **Colour**, with "holds a colour" meaning a validated belt)? Or should we keep "belt" for both?

➡️ Recommended: **Belt** = one consultant's attempt at one colour in one discipline, with a lifecycle. **Colour** = the rank. "Holding" a colour means having a validated belt of that colour. Avoid: *grade*, *level*, *certification*.

❓ **Q2 - Is a refused belt a dead end or a retry?** Today, after REFUSED the consultant can request again and gets the **same colour**, starting from scratch with no mentor and no objectives. Is starting fresh what you want, or should a retry carry over the mentor and objectives?

➡️ Recommended: fresh start, as coded. A refusal is final for that belt. The consultant requests a new belt of the same colour.

❓ **Q3 - Role separation on one belt.** People can hold several roles (Grace is consultant + mentor, Margaret is mentor + sensei). The code blocks a consultant from mentoring their own belt. It does **not** stop a sensei from deciding a belt they mentored: Margaret mentors B-3 and could also validate it. Is that allowed?

➡️ Recommended: **no**. The sensei's decision is independent of the coaching, so a sensei can't decide a belt they mentored (or their own). This becomes a business rule for a future story; the code isn't touched now.

❓ **Q4 - Are mentors and senseis scoped to a discipline?** Right now any mentor can coach any discipline, and any sensei can decide any discipline. Is that intended?

➡️ Recommended: global for now. Record it as a deliberate simplification, so no agent "fixes" it without a story.

❓ **Q5 - The product intent: "no exam, no certificate mill."** The README says objectives are concrete, are agreed between mentor and consultant, and get validated as they happen in real work. Should that go into `CONTEXT.md` as a **product principle**? It would mean: no catalogue of mandatory objectives per colour, no scores, no automated validation. It would block a whole class of wrong proposals.

➡️ Recommended: **yes**, stated as: *"Objectives are tailored by the mentor for each belt; Blackbelt never prescribes or automatically checks them. A human always validates."*

Answer as many as you like (e.g. "1 ok, 2 ok, 3 allowed because…"). Round 2 will cover the lifecycle vocabulary (submission, awaiting validation) and the foundational ADRs (no-dependency Node, JSON-file state, CLI as the primary surface).

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: 1 ok, 2 ok, 3 allowed: we are a small team, 4 ok, 5 ok | 1 keep belt for both, the rest as recommended -->
### You

1 ok: Belt is the attempt, Colour is the rank. 2 ok: a refusal is final, the consultant requests a new belt of the same colour. 3 ok: a sensei never decides a belt they mentored, nor their own; that's for a later story. 4 ok: global for now, a deliberate simplification. 5 yes, exactly that principle.

<!-- pdsf-turn: agent -->
### Agent

⏺ Write(CONTEXT.md)

I've written round 1 into `CONTEXT.md`:
- an **Intent** section holding the "no exam, no certificate mill" principle
- **Progression** terms: Discipline, Colour, Belt, Objective
- **People** terms: Consultant, Mentor, Sensei

The sensei's independence rule (a sensei never decides a belt they mentored or their own) is recorded as intent for a later story. Mentors and senseis being global across disciplines is marked as a deliberate simplification.

---

### Round 2: the lifecycle and the foundational decisions

❓ **Q6 - Lifecycle vocabulary.** The code has `REQUESTED → MENTOR_ASSIGNED → IN_PROGRESS → NEED_VALIDATION → VALIDATED / REFUSED`, and BELT-US-1 says "submit" and "awaits validation". I'd add:
- **Submission**: the consultant declares the belt done and hands it to a sensei.
- **Decision**: the sensei validates or refuses.
- Status names stay as in the code, but prose uses "awaiting validation" for `NEED_VALIDATION`.

➡️ Recommended: yes. Also state that the lifecycle is **forward-only**: no withdrawal, no reopening, no going back a step. BELT-US-1 already excludes withdrawal.

❓ **Q7 - Invariants worth stating.** Two rules from the code that a generic agent could easily break:
- **One open belt per discipline** per consultant (open means not validated and not refused).
- **Objectives are only added or validated while the belt is in progress**, so a submitted belt's objectives are frozen.

Should both go into the glossary?

➡️ Recommended: yes, as one line each under Belt and Objective.

❓ **Q8 - ADR: no runtime or dev dependencies.** Node 18+ built-ins only (`node:test`, `node:fs`), with no `npm install`. Without this ADR, an agent will happily add Jest, Commander or a DB driver. Is this a deliberate constraint, and why? Is it for the "lite" demo's portability, or a lasting rule?

➡️ Recommended: a deliberate, lasting constraint ("runs anywhere Node runs, nothing to install"). New dependencies need an ADR.

❓ **Q9 - ADR: state in a local JSON file, seeded from `data/seed.json`.** Is the file the real persistence model for this product, or a placeholder until a real store exists?

➡️ Recommended: deliberate for the lite version. A single local JSON file, with no concurrency handling and one user at a time. Moving to a real store is a future decision with its own ADR.

❓ **Q10 - ADR: the CLI is the primary surface.** There's no UI and no API. The CLI is the contract users script against, and it's what agentic tests will drive (shell/tmux). That includes the convention that a domain refusal prints `refused: …` and exits with a distinct code. Should we record that the CLI is *the* surface and that its output and refusals form a contract?

➡️ Recommended: yes, one ADR. The refusal convention goes in the ADR, not in `CONTEXT.md`.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: All as recommended, but the JSON file is only a placeholder | 6 to 9 ok, 10 skip the ADR for now -->
### You

6 ok, forward-only. 7 yes, both. 8 yes: a lasting constraint, nothing to install; a new dependency needs an ADR. 9 deliberate for the lite version, one local JSON file. 10 yes, the CLI is the surface and its refusals are a contract.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(python3 - <<'EOF')
⏺ Bash(sed -i 's/a usage error exits$/an unknown command exits/' docs/adr/0003-cli-primary-surfa…)
⏺ Bash(rmdir .scratch 2>/dev/null; git status -s)

Your round 2 answers are in `CONTEXT.md` and three ADRs. Nothing is committed yet.

**`CONTEXT.md` additions**
- **Belt lifecycle** (forward-only), plus **Submission** and **Decision** as terms.
- The one-open-belt-per-discipline rule, under **Belt**.
- Objectives are frozen once a belt is submitted, under **Objective**.

**ADRs in `docs/adr/`**
- **0001 – no dependencies.** Node built-ins only; any new dependency needs its own ADR.
- **0002 – state in one local JSON file.** Deliberate for the lite version: one user at a time, no concurrency handling. A real store would need its own ADR.
- **0003 – the CLI is the primary surface.** A refusal prints `refused: <reason>` on stderr, exits with code 2 and leaves the state unchanged. An unknown command exits with code 1.

I also deleted the `docs/adr/.gitkeep` placeholder, since the folder now has real files.

**Wiring smoke check**
- **Technical backlog:** `.scratch/` is writable.
- **Business backlog:** it's the local `business-backlog/` folder, and BELT-US-1 is `Ready`.
- **Agentic-test driver:** the CLI drives the real system. I ran it against a throwaway state file: `decide B-3 margaret validated` was refused as expected with exit code 2, and the state didn't change. `tmux` is available.
- **Tests:** `node --test` passes all 30.

I've covered every open question, and only two points sit outside this session:
- **The sensei independence rule** is recorded as intent but isn't enforced in the code yet. It needs its own story, which `/to-us` can write.
- **Missing arguments (e.g. `request` with nothing after it) aren't covered by the 0003 contract.** They currently show up as a domain refusal with exit code 2, not a usage error. I left that unspecified rather than decide it for you.

**Does this match what we agreed?** If so, I'll commit it to `develop` as "Bootstrap project context: glossary + foundational ADRs" (that's where this setup work belongs). Then the next steps are `/verify-factory`, followed by `/grill-with-docs` on BELT-US-1 → `/to-spec` → `/to-tickets` → `/implement`.

<!-- pdsf-turn: learner -->
<!-- pdsf-choices: Let me review the files first | Commit, and settle the missing-arguments case as a usage error -->
### You

Yes, it matches. Commit it on develop.

<!-- pdsf-turn: agent -->
### Agent

⏺ Bash(git rev-parse --abbrev-ref HEAD && git add CONTEXT.md docs/adr && git commit -q -F - <<'E…)

I committed it on `develop` as `84c2449` ("Bootstrap project context: glossary + foundational ADRs"). The working tree is clean, and I didn't push.

The commit contains:
- **`CONTEXT.md`**: the product principle ("no exam, no certificate mill") and the glossary covering the belt progression and the three roles.
- **`docs/adr/0001` to `0003`**: no dependencies, state in one local JSON file, and the CLI as the primary surface whose refusals are a contract.

Every agent now reads these files first, and every later `integration/*` branch starts from them.

**Next:** run `/verify-factory` for the full health check. Then design BELT-US-1 (the story where a consultant submits a belt for the sensei's validation) with `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement`.

**Left open:**
- **Sensei independence rule:** recorded as intent but not enforced in the code. It needs its own story, which `/to-us` can write.
- **Missing arguments on a CLI command:** ADR 0003 doesn't cover them. They currently get a refusal with exit code 2 rather than a usage error, which a future grilling can settle.
