# No dependencies: Node built-ins only

Without this, a competent agent would add a test runner, a CLI parser or a database driver from npm.
Blackbelt runs on Node 18+ built-ins only (`node:test`, `node:fs`…) with nothing to install, so it
runs anywhere Node runs. This is a lasting constraint: any new runtime or dev dependency needs its own
ADR.
