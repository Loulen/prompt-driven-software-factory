# The CLI is the primary surface, and its refusals are a contract

Without this, a competent agent would treat the CLI as a thin debug wrapper and freely reshape its
output, or validate features through unit tests only.
The CLI is the product's only surface: users script against it and agentic tests drive it from a
shell. Its commands and output are a contract. A domain rule violation is a **refusal**: it prints
`refused: <reason>` on stderr, exits with code 2 and leaves the state unchanged; an unknown command exits
with code 1.
