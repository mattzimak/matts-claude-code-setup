---
paths:
  - "dev/**"
---

# You are editing a file under dev/

The dev/ domain brain is NOT auto-loaded from a root session. Before finishing this edit:

1. Read `dev/CLAUDE.md` and the specific `dev/<project>/CLAUDE.md` for the product you are touching.
2. Document the change at three levels: feature, user-facing flow, and technical detail.
3. Any site ships only after the quality audit defined in `dev/CLAUDE.md`.

<!--
Why this file exists: path-scoped rules load only when Claude reads a file matching
the `paths` globs, not on every tool call. That makes them the right place for a
thin pointer to a domain brain. Keep them pointers, never copies: a duplicated rule
drifts from its source within weeks.

This complements domain-router.sh. The router fires on the PROMPT's words; this
fires on the FILES actually touched, so it still catches a dev edit that began
with a prompt the router's keywords missed.
-->
