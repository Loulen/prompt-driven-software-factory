# Tutorial modes

One folder per shipped mode, `<id>-<slug>/`, holding a `mode.md` (frontmatter `title:`,
`summary:`) and a `play.sh`. The entry script offers only the folders that hold both. The full
contract (invocation, environment, exit status) is in [`../README.md`](../README.md#modes-contract).

Shipped: [`a1` narrated replay](a1-narrated-replay/mode.md), [`b` real agent](b-real-agent/mode.md). Planned:
`a2` simulated session.
