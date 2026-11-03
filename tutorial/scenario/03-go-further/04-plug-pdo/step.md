---
title: PDSF and PDO, two independent tools
kind: reading
---

## What you do

Nothing to install. You just did everything with PDSF alone: skills in your repo, your harness,
your terminal. **PDO** (Prompt Driven Orchestrator) is a separate, optional tool. It chains agent
sessions into pipelines (for example grill → spec → tickets → implement loops) and runs them for
you. You don't need it to use PDSF.

## Under the hood

PDSF is the **method and its skills**; PDO is **one way to orchestrate** them. A PDO pipeline node
is just an agent session that runs a PDSF skill in your repo, like you did by hand. Plug it in when
you want to run several tickets in parallel or unattended. A shared PDO instance is also a way for
a facilitator to run the real-agent tutorial for participants without their own subscription.
