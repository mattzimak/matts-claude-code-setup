#!/bin/bash
# UserPromptSubmit hook - Evidence-audit directive.
#
# Injects a verification/evidence directive into EVERY prompt so progress
# reports are always audited against actual tool results from the session.
# Deterministic harness injection - survives long sessions where CLAUDE.md
# instructions can drift out of the context window.
#
# Output contract: UserPromptSubmit hooks inject stdout via
# hookSpecificOutput.additionalContext.

DIRECTIVE='EVIDENCE-AUDIT (MANDATORY, every progress report this turn):
- Before reporting progress, audit each claim against a tool result from this session.
- Only report work you can point to evidence for. If something is not verified, say so.
- If a step failed, state that with the output. Do not report success you cannot prove.'

jq -n --arg ctx "$DIRECTIVE" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

exit 0
