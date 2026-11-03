---
title: Where to look tomorrow
kind: reading
---

## What you do

Tomorrow, on your own project, you start from two documents of the PDSF repository:

- the **README**: the method in one diagram, the pipeline of commands, every skill and its role;
- **`docs/INSTALL.md`**: the exact installer invocations, every `PDSF_*` variable, the monorepo
  layout (one factory per context), the offline mode, the other install channels.

Then the same two gestures as in chapter 1: run the installer in your repo, then `/build-factory`.

## Under the hood

Everything you saw lives in your repo, as plain files: the skills in `.agents/skills/`, the ports
in `docs/agents/`, the domain in `CONTEXT.md` and `docs/adr/`. Open any `SKILL.md`: it is the
prompt the agent receives, nothing hidden. You can read them, and tailor them for your project.
