# State in one local JSON file

Without this, a competent agent would introduce a database or add locking and concurrency handling.
For the lite version, all state lives in a single local JSON file (seeded from `data/seed.json`,
location overridable via `BLACKBELT_STATE`), read and rewritten whole on each command, for one user
at a time. Moving to a real store is a future decision with its own ADR.
