# Tutorial modes

One folder per shipped mode, `<id>-<slug>/`, holding a `mode.md` (frontmatter `title:`,
`summary:`) and a `play.sh`. The entry script offers only the folders that hold both. The full
contract (invocation, environment, exit status) is in [`../README.md`](../README.md#modes-contract).

Planned: `a1` narrated replay, `a2` simulated session, `b` real agent.
