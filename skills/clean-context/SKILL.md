---
name: clean-context
description: Prune the project's accumulated context by the factory : CONTEXT.md, the ADRs, and code comments. A heavy, occasional refactor on its own branch and PR. Use on "clean the context", "prune the docs/ADRs/comments", or when the domain docs have visibly bloated.
disable-model-invocation: true
---

# Clean Context

An occasional, repo-wide refactor that prunes the context the factory accumulates: `CONTEXT.md`,
`docs/adr/`, and code comments.

1. ADRs should strictly adhere to /domain-modeling @../ADR-FORMAT.md, especially the surprising part

In general, the md files and comments :
2. should not bear history : this is the role of version control (and ADRs for surprising decisions taken in the past). 
3. They should not explain code, the code is its own documentation and ground truth.
They should only bear business logic and intent.

Delete anything that do not follow this. Make sure the rest is concise.

# Interactivity

After the analysis, give a report of what ADRs were deemed problematic, and give the user the option of deleting/reformating part of the content, or dropping the entire ADR. Give a list of ADRs with your opinion. It should be formated like :

```
📁 **ADR 1** - **<ADR title>**: 
<❌ or ✅> Hard to reverse 
<❌ or ✅> Surprising without context 
<❌ or ✅> The result of a real trade-off 

➡️ <your recommended action and why (2 line max)>
```
