# The tutorial lives outside `skills/`, on a rewritten fixture, with recorded agent steps

Without this ADR, a competent agent would (1) put tutorial material under `skills/` like every
other skill — and `install.sh` enumerates `skills/*/`, so every user's factory would ship it;
(2) seed the tutorial by vendoring Ippon's Blackbelt (or blackbelt-new-wave) into this repo — both
are internal GitLab projects, `UNLICENSED`, while this repo is public; (3) "simulate" the agent with
improvised or generated output; or (4) tell the learner to type `claude` in their own shell, which
launches their real agent and spends tokens.

Decided:

- The tutorial lives under its own top-level folder. `install.sh` never installs any of it.
- The fixture is `blackbelt-lite`: a from-scratch, zero-dependency rewrite of the Blackbelt
  domain. Nothing from the internal repos is copied.
- **One path, in a simulated harness.** The tutorial is a single zero-dependency app (Node 18,
  no `npm install`) hosting a **tutorial shell** and a **simulated harness**: the learner types
  `claude` *inside the app*. No mode menu, no real-agent mode, no guide skill — after the
  tutorial, the learner uses PDSF on a real project.
- A simulated step replays artifacts **recorded from a real run** of the skills (the maintainers'
  recorder re-records them when a skill changes) and is flagged simulated; deterministic steps
  (install, git, checks) always run for real. The learner must see where the agent's work starts
  and stops.
- Entry is a `curl … | sh` bootstrap modelled on `install.sh` (fetch PDSF to a temp dir, talk
  through `/dev/tty`), so no clone is needed. `PDSF_REF` selects the branch, which is how a
  recette runs the real gesture on an unreleased branch.

## Considered Options

- **Clone Blackbelt at tutorial start (pinned SHA).** Rejected: it locks the tutorial to people
  with Ippon GitLab access; the audience is anyone discovering PDSF.
- **A PDO Tour or PDO pipeline as the tutorial.** Rejected as the primary surface: PDSF must be
  understood without PDO.
- **Several tutorial modes (narrated replay, stand-in `claude` on `PATH`, real agent + guide
  skill).** Tried in the first iteration and rejected at recette: walls of plain text, hard to
  validate, and a stand-in `claude` on `PATH` cannot draw the coach or the progress. One path won.
- **Hand-written agent replies.** Rejected: shorter to edit, but they drift from what the skills
  really do.
