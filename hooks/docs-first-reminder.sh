#!/bin/bash
# UserPromptSubmit hook - documentation-first enforcement.
#
# Models answer fast-moving tools from training memory, and the memory is stale.
# When a prompt mentions a tool you want grounded in CURRENT official docs, this
# injects a mandatory reminder to consult those docs (here via the Context7 MCP
# server) BEFORE answering, building, or debugging.
#
# Topics are independent: each matched topic appends its own reminder, so a
# prompt that mentions two tools gets both. To add a topic, copy an `if` block.
#
# Output contract: additionalContext nested inside hookSpecificOutput. Emit
# nothing when nothing matches.

PROMPT="$(jq -r '.prompt // empty')"

CONTEXT=""
append() { [ -n "$CONTEXT" ] && CONTEXT+=$'\n\n'; CONTEXT+="$1"; }

# --- Claude Code itself: its surfaces change often ---
if printf '%s' "$PROMPT" | grep -iqE 'claude[ -]?code'; then
  append 'DOCUMENTATION-FIRST (Claude Code) - MANDATORY this turn: before answering any question about Claude Code configuration, or changing hooks, settings.json, skills, subagents, MCP servers, CLAUDE.md or permissions, consult CURRENT official documentation via Context7 (library id /websites/code_claude) as the primary source. Do not answer from memory. Cite what the docs return.'
fi

# --- Example: an automation platform whose node parameters shift between versions ---
if printf '%s' "$PROMPT" | grep -iqE 'n8n'; then
  append 'DOCUMENTATION-FIRST (n8n) - MANDATORY this turn: before building, modifying or debugging any workflow, node, expression or API call, consult current n8n documentation via Context7. Do not rely on memory for node parameters, expression syntax or API behaviour.'
fi

if [ -n "$CONTEXT" ]; then
  jq -n --arg ctx "$CONTEXT" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
fi

exit 0
