# The tutorial lives outside `skills/`, on a rewritten fixture, with recorded agent steps

Without this ADR, a competent agent would (1) put the tutorial's guide skill under `skills/` like
every other skill — and `install.sh` enumerates `skills/*/`, so every user's factory would ship a
tutorial skill; (2) seed the tutorial by vendoring Ippon's Blackbelt (or blackbelt-new-wave) into
this repo — both are internal GitLab projects, `UNLICENSED`, while this repo is public; or
(3) "simulate" the agent with improvised or generated output.

Decided:

- The tutorial lives under its own top-level folder. Its guide skill is copied **only** into the
  tutorial workspace by the tutorial's entry script, never by `install.sh`.
- The fixture is `blackbelt-lite`: a from-scratch, zero-dependency rewrite of the Blackbelt
  domain. Nothing from the internal repos is copied.
- A simulated step replays artifacts **recorded from a real run** of the skills, and says it is
  simulated; deterministic steps (install, git, checks) always run for real. The learner must see
  where the agent's work starts and stops.
- Entry is a `curl … | sh` bootstrap modelled on `install.sh` (fetch PDSF to a temp dir, talk
  through `/dev/tty`), so no clone is needed.

## Considered Options

- **Clone Blackbelt at tutorial start (pinned SHA).** Rejected: it locks the tutorial to people
  with Ippon GitLab access; the audience is anyone discovering PDSF.
- **A PDO Tour or PDO pipeline as the tutorial.** Rejected as the primary surface: PDSF must be
  understood without PDO. The real-agent mode may be run from a PDO instance; that is a doc
  recipe, not a coupling.
