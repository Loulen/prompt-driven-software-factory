---
title: Grill the business story
kind: agent
command: /grill-with-docs
---

## What you do

A human (the PO) selected `Belt US-1 [user] Submit my belt for sensei validation` in the business
backlog: it is `Status: Ready`. You type `/grill-with-docs` and point it at the story. The agent
reads it, reads `CONTEXT.md` and the ADRs, then grills you on what the story leaves open: what does
"submit" change on the belt? Who may submit? What does the refusal say?

## Under the hood

This is where the human effort of the method concentrates: one to two hours per story on a real
project. The session creates the story's **integration branch**, `integration/belt-us-1-<slug>`,
from `develop`. It is named after the business story, because the spec does not exist yet. It
writes its decisions there as they settle: new terms in `CONTEXT.md`, an ADR when a decision had a
real alternative.

The rule "a belt is submitted only when every objective is validated, otherwise refused listing the
remaining ones" is the kind of decision the grilling pins down before any code exists.
